import { createHash } from "node:crypto";
import { profilePayload, requireValue, requireProfileHue } from "./protocol.js";
import { requireLiveAccount } from "./account-deletion.js";

export function ownerRecord(input) {
  requireValue(input && typeof input === "object");
  const { key, version } = input;
  requireValue(typeof key === "string" && /^(profile|(event|rating|note):\d+)$/.test(key));
  requireValue(version && Number.isFinite(version.modifiedAt) && Math.abs(version.modifiedAt) < 1e14);
  requireValue(typeof version.changeID === "string" && version.changeID.length > 0 && version.changeID.length <= 200);
  const record = { key, version: { modifiedAt: version.modifiedAt, changeID: version.changeID } };
  if (key === "profile") {
    requireValue(input.badgeName == null || (typeof input.badgeName === "string" && input.badgeName.length <= 40));
    requireProfileHue(input.hue);
    return { ...record, value: null, badgeName: input.badgeName?.trim() || null, hue: input.hue };
  }
  const [kind, rawID] = key.split(":");
  const id = Number(rawID);
  requireValue(Number.isSafeInteger(id) && id >= 0 && String(id) === rawID);
  const value = input.value;
  requireValue(value && value.kind === kind && value.id === id);
  const sanitized = { kind, id, isSaved: false, rating: 0, iconName: null, noteText: "" };
  if (kind === "event") {
    requireValue(typeof value.isSaved === "boolean");
    sanitized.isSaved = value.isSaved;
  } else if (kind === "rating") {
    requireValue(Number.isInteger(value.rating) && value.rating >= -1 && value.rating <= 3);
    requireValue(value.iconName == null || (typeof value.iconName === "string" && value.iconName.length <= 100));
    sanitized.rating = value.rating;
    sanitized.iconName = value.iconName ?? null;
  } else {
    requireValue(typeof value.noteText === "string" && Buffer.byteLength(value.noteText, "utf8") <= 1_000_000);
    sanitized.noteText = value.noteText;
  }
  return { ...record, value: sanitized };
}

function content(record) {
  if (record.key === "profile") return `${record.badgeName ?? ""}\n${record.hue ?? ""}`;
  const value = record.value;
  if (value.kind === "event") return `event:${value.isSaved}`;
  if (value.kind === "rating") return `rating:${value.rating}:${value.iconName ?? ""}`;
  return `note:${value.noteText}`;
}
const order = (a, b) => a === b ? 0 : a > b ? 1 : -1;
export function compareOwnerRecords(a, b) {
  return order(a.version.modifiedAt, b.version.modifiedAt) ||
    order(a.version.changeID, b.version.changeID) ||
    (a.key === "profile" && b.key === "profile"
      ? order(a.badgeName ?? "", b.badgeName ?? "") || order(a.hue ?? 30, b.hue ?? 30)
      : order(content(a), content(b)));
}

async function archivedSharedRecords(db, uid, sharedProfile) {
  return db.runTransaction(async tx => {
    await requireLiveAccount(tx, db, uid);
    const categories = sharedProfile.collection("categories");
    const [saved, ratings] = await tx.getAll(categories.doc("savedEvents"), categories.doc("ratings"));
    const profile = profilePayload({
      name: "Archive", hue: 0,
      savedEventIDs: saved.get("savedEventIDs") ?? [],
      artistPreferences: ratings.get("artistPreferences") ?? [],
    });
    // An existing private record, including a tombstone, wins over this fallback.
    const version = { modifiedAt: -99_999_999_999_999, changeID: "archive-shared-fallback" };
    return [
      ...profile.savedEventIDs.map(id => ownerRecord({
        key: `event:${id}`, version, value: { kind: "event", id, isSaved: true },
      })),
      ...profile.artistPreferences.map(({ artistID: id, rating, iconName }) => ownerRecord({
        key: `rating:${id}`, version, value: { kind: "rating", id, rating, iconName },
      })),
    ];
  });
}

async function projectArchiveRecord(tx, sharedProfile, record, archiveSharing) {
  const { value } = record;
  if (value?.kind !== "event" && value?.kind !== "rating") return;
  const managed = (await tx.get(sharedProfile)).get("archiveSharing") === true;
  if (!archiveSharing && !managed) return;
  const isEvent = value.kind === "event";
  const ref = sharedProfile.collection("categories").doc(isEvent ? "savedEvents" : "ratings");
  const category = await tx.get(ref);
  if (!managed) tx.set(sharedProfile, { archiveSharing: true }, { merge: true });
  if (isEvent) {
    const ids = new Set(category.get("savedEventIDs") ?? []);
    if (value.isSaved) ids.add(value.id);
    else ids.delete(value.id);
    tx.set(ref, { savedEventIDs: [...ids].sort((a, b) => a - b) });
  } else {
    const ratings = (category.get("artistPreferences") ?? []).filter(rating => rating.artistID !== value.id);
    if (value.rating !== 0) ratings.push({ artistID: value.id, rating: value.rating, iconName: value.iconName });
    tx.set(ref, { artistPreferences: ratings.sort((a, b) => a.artistID - b.artistID) });
  }
}

export async function syncOwnerRecords(db, uid, edition, input, archiveSharing = false) {
  requireValue(Array.isArray(input) && (archiveSharing || input.length > 0) && input.length <= 50);
  requireValue(Buffer.byteLength(JSON.stringify(input), "utf8") < 8_000_000);
  const root = db.collection("users").doc(uid).collection("profileEditions").doc(edition);
  const sharedProfile = db.collection("friendProfileEditions").doc(edition).collection("profiles").doc(uid);
  if (input.length === 0) {
    return { records: await archivedSharedRecords(db, uid, sharedProfile), archiveSharing };
  }
  const records = input.map(ownerRecord);
  const returned = new Map();
  // Individual transactions also handle a large note being deleted without exceeding
  // Firestore's transaction size limit. Partial requests are safe to retry by version.
  for (const incoming of records) {
    const result = await db.runTransaction(async tx => {
      await requireLiveAccount(tx, db, uid);
      const ref = root.collection("records").doc(incoming.key);
      const previous = (await tx.get(ref)).data();
      const winner = !previous || compareOwnerRecords(incoming, previous) > 0 ? incoming : previous;
      await projectArchiveRecord(tx, sharedProfile, winner, archiveSharing);
      if (incoming.value?.kind === "note") {
        for (const version of [previous, incoming]) {
          if (version?.value?.noteText) {
            const id = createHash("sha256").update(JSON.stringify([
              version.key, version.version.modifiedAt, version.version.changeID, version.value.noteText,
            ])).digest("hex");
            tx.set(root.collection("noteVersions").doc(id), version);
          }
        }
      }
      if (winner === incoming) tx.set(ref, incoming);
      return winner;
    });
    returned.set(result.key, result);
  }
  return { records: [...returned.values()], ...(archiveSharing ? { archiveSharing } : {}) };
}
