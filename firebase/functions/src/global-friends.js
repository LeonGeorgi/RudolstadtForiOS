import { createHash, randomBytes } from "node:crypto";
import { Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FriendError, requireValue, profilePayload } from "./protocol.js";
import { requireLiveAccount } from "./account-deletion.js";

export function permissions(value) {
  requireValue(value && typeof value.savedEvents === "boolean" && typeof value.ratings === "boolean" && (value.notes === undefined || typeof value.notes === "boolean"));
  return { savedEvents: value.savedEvents, ratings: value.ratings, notes: value.notes === true };
}
const noSharing = { savedEvents: false, ratings: false, notes: false };
const validUID = value => typeof value === "string" && /^[A-Za-z0-9:_-]{1,128}$/.test(value);
export function validateGlobalInvite(value, uid, now) {
  requireValue(value && value.version === 2, "not-found");
  requireValue(value.owner !== uid, "failed-precondition", "self-invite");
  requireValue(!value.usedBy && !value.revoked && value.expiresAt.toMillis() > now, "failed-precondition", "invite-unavailable");
}

export function globalFriendFunctions(db, options) {
  const identity = uid => db.collection("friendIdentities").doc(uid);
  const member = uid => db.collection("friendships").doc(uid);
  const friend = (uid, other) => member(uid).collection("friends").doc(other);
  const inviteRef = token => {
    requireValue(typeof token === "string" && /^[A-Za-z0-9_-]{43}$/.test(token));
    return db.collection("friendInvitesV2").doc(createHash("sha256").update(token).digest("hex"));
  };
  const handler = run => onCall(options, async request => {
    try {
      requireValue(request.auth && request.auth.token.firebase?.sign_in_provider !== "anonymous", "unauthenticated");
      requireValue(request.data?.protocol === 2, "failed-precondition", "friends-upgrade-required");
      requireValue(request.data.owner === request.auth.uid, "permission-denied");
      const uid = request.auth.uid;
      requireValue(!(await db.collection("accountDeletions").doc(uid).get()).exists, "permission-denied");
      return await run(uid, request.data);
    } catch (error) {
      if (error instanceof FriendError) throw new HttpsError(error.code, error.message);
      throw error;
    }
  });
  return {
    setFriendIdentity: handler(async (uid, data) => {
      const value = profilePayload({ ...data.identity, savedEventIDs: [], artistPreferences: [] });
      await db.runTransaction(async tx => {
        await requireLiveAccount(tx, db, uid);
        tx.set(identity(uid), { name: value.name, hue: value.hue });
      });
      return { identity: { name: value.name, hue: value.hue } };
    }),
    publishFriendProfile: handler(async (uid, data) => {
      requireValue(typeof data.edition === "string" && /^[a-z][a-z0-9-]{0,50}-[0-9]{4}$/.test(data.edition));
      const value = profilePayload({ ...data.profile, name: "validated-data", hue: 0 });
      const profile = db.collection("friendProfileEditions").doc(data.edition).collection("profiles").doc(uid);
      const categories = profile.collection("categories");
      await db.runTransaction(async tx => {
        await requireLiveAccount(tx, db, uid);
        // Older clients can still sync individual records, but their full snapshot
        // must not replace an archive projection managed by syncOwnProfile.
        if ((await tx.get(profile)).get("archiveSharing") === true) return;
        tx.set(categories.doc("savedEvents"), { savedEventIDs: value.savedEventIDs });
        tx.set(categories.doc("ratings"), { artistPreferences: value.artistPreferences });
      });
      return { published: true };
    }),
    createFriendInvite: handler(async (uid, data) => {
      const sharing = permissions(data.sharing), token = randomBytes(32).toString("base64url"), ref = inviteRef(token), now = Date.now();
      await db.runTransaction(async tx => {
        await requireLiveAccount(tx, db, uid);
        const [person, metadata] = await Promise.all([tx.get(identity(uid)), tx.get(member(uid))]);
        requireValue(person.exists, "failed-precondition", "identity-required");
        requireValue(now - (metadata.get("lastInviteAt")?.toMillis() ?? 0) >= 10_000, "resource-exhausted");
        if (metadata.get("inviteID")) tx.set(db.collection("friendInvitesV2").doc(metadata.get("inviteID")), { revoked: true }, { merge: true });
        tx.set(ref, { version: 2, owner: uid, sharing, expiresAt: Timestamp.fromMillis(now + 7 * 86400_000) });
        tx.set(member(uid), { inviteID: ref.id, lastInviteAt: Timestamp.fromMillis(now) }, { merge: true });
      });
      return { token };
    }),
    previewFriendInvite: handler(async (uid, data) => {
      const invite = (await inviteRef(data.token).get()).data();
      validateGlobalInvite(invite, uid, Date.now());
      requireValue(!(await db.collection("accountDeletions").doc(invite.owner).get()).exists, "not-found");
      const person = await identity(invite.owner).get();
      requireValue(person.exists, "not-found");
      return { name: person.get("name"), sharing: permissions(invite.sharing) };
    }),
    acceptFriendInvite: handler(async (uid, data) => {
      const sharing = permissions(data.sharing), ref = inviteRef(data.token);
      await db.runTransaction(async tx => {
        await requireLiveAccount(tx, db, uid);
        const invite = (await tx.get(ref)).data();
        validateGlobalInvite(invite, uid, Date.now());
        await requireLiveAccount(tx, db, invite.owner);
        const [own, other, existing, reverse] = await Promise.all([
          tx.get(identity(uid)), tx.get(identity(invite.owner)), tx.get(friend(uid, invite.owner)), tx.get(friend(invite.owner, uid)),
        ]);
        requireValue(own.exists && other.exists, "failed-precondition", "identity-required");
        requireValue(existing.exists === reverse.exists, "failed-precondition");
        if (!existing.exists) {
          const receiving = permissions(invite.sharing);
          tx.set(friend(uid, invite.owner), { uid: invite.owner, sharing, receiving });
          tx.set(friend(invite.owner, uid), { uid, sharing: receiving, receiving: sharing });
        }
        tx.update(ref, { usedBy: uid });
      });
      return { accepted: true };
    }),
    updateFriendSharing: handler(async (uid, data) => {
      requireValue(validUID(data.uid) && data.uid !== uid);
      const sharing = permissions(data.sharing);
      const connection = await db.runTransaction(async tx => {
        await requireLiveAccount(tx, db, uid); await requireLiveAccount(tx, db, data.uid);
        const [before, reverse] = await Promise.all([tx.get(friend(uid, data.uid)), tx.get(friend(data.uid, uid))]);
        requireValue(before.exists && reverse.exists, "not-found");
        tx.update(before.ref, { sharing }); tx.update(reverse.ref, { receiving: sharing });
        return { uid: data.uid, sharing, receiving: permissions(before.get("receiving") ?? noSharing) };
      });
      return { connection };
    }),
    friendConnectionStatus: handler(async (uid, data) => {
      requireValue(validUID(data.uid) && data.uid !== uid);
      const [record, deleting] = await Promise.all([friend(uid, data.uid).get(), db.collection("accountDeletions").doc(data.uid).get()]);
      return { connection: record.exists && !deleting.exists ? record.data() : null };
    }),
    removeFriend: handler(async (uid, data) => {
      requireValue(validUID(data.uid) && data.uid !== uid);
      await db.runTransaction(async tx => {
        await requireLiveAccount(tx, db, uid);
        tx.delete(friend(uid, data.uid)); tx.delete(friend(data.uid, uid));
      });
      return { removed: true };
    }),
  };
}
