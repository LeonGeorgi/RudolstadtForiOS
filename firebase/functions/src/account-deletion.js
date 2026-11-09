import { createHash } from "node:crypto";
import { getAuth } from "firebase-admin/auth";
import { Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { FriendError, requireValue } from "./protocol.js";

export const deletionRef = (db, uid) => db.collection("accountDeletions").doc(uid);
const digest = value => createHash("sha256").update(value).digest("hex");

// Every account write reads this fence inside its transaction. Creating the
// deletion job therefore also waits for or invalidates already running writes.
export async function requireLiveAccount(tx, db, uid) {
  requireValue(!(await tx.get(deletionRef(db, uid))).exists, "permission-denied", "account-deleting");
}

async function ignoreMissing(operation) {
  try { return await operation(); }
  catch (error) { if (error.code !== "auth/user-not-found") throw error; }
}

async function eraseQuery(db, query) {
  while (true) {
    const page = await query.limit(300).get();
    if (page.empty) return;
    const batch = db.batch();
    for (const row of page.docs) batch.delete(row.ref);
    await batch.commit();
  }
}

export async function eraseAccountData(db, auth, uid) {
  // Stop refreshes first; clients with cached ID/custom tokens are fenced too.
  await ignoreMissing(() => auth.updateUser(uid, { disabled: true }));
  await ignoreMissing(() => auth.revokeRefreshTokens(uid));
  await eraseQuery(db, db.collectionGroup("friends").where("uid", "==", uid));
  await db.recursiveDelete(db.collection("friendships").doc(uid));
  await db.collection("friendIdentities").doc(uid).delete();
  for (const edition of await db.collection("friendProfileEditions").listDocuments()) {
    await db.recursiveDelete(edition.collection("profiles").doc(uid));
  }
  await eraseQuery(db, db.collection("friendInvitesV2").where("owner", "==", uid));
  await eraseQuery(db, db.collection("friendInvitesV2").where("usedBy", "==", uid));
  for (const edition of await db.collection("friendEditions").listDocuments()) {
    await db.recursiveDelete(edition.collection("members").doc(uid));
    await db.recursiveDelete(edition.collection("profiles").doc(uid));
  }
  await eraseQuery(db, db.collection("friendInvites").where("owner", "==", uid));
  await eraseQuery(db, db.collection("friendInvites").where("usedBy", "==", uid));
  await eraseQuery(db, db.collection("accountKeySecrets").where("uid", "==", uid));
  await db.collection("accountKeyOwners").doc(uid).delete();
  await db.collection("accountKeyLimits").doc(digest(`replace:${uid}`)).delete();
  await db.recursiveDelete(db.collection("users").doc(uid));
  await ignoreMissing(() => auth.deleteUser(uid));
}

export async function processAccountDeletion(db, auth, uid, now = Date.now()) {
  const ref = deletionRef(db, uid);
  const job = (await ref.get()).data();
  if (!job) return;
  await eraseAccountData(db, auth, uid);
  // Custom tokens minted just before deletion can still exist for one hour.
  // Keep only this minimal retry/fence record for two hours, then erase it and
  // any Auth-only account re-created with an old token. No profile data remains.
  if (now >= job.blockedUntil.toMillis()) await ref.delete();
  else await ref.update({ cleaned: true });
}

export function accountDeletionFunctions(db, options) {
  const auth = getAuth();
  const workerOptions = { ...options, timeoutSeconds: 540 };
  return {
    accountDeletionStatus: onCall(options, async request => {
      const owner = request.data?.owner;
      if (typeof owner !== "string" || !/^[A-Za-z0-9:_-]{1,128}$/.test(owner)) throw new HttpsError("invalid-argument", "invalid-owner");
      if ((await deletionRef(db, owner).get()).exists) return { deleted: true };
      const user = await ignoreMissing(() => auth.getUser(owner));
      return { deleted: !user };
    }),
    deleteAccount: onCall(workerOptions, async request => {
      try {
        const { owner, receipt } = request.data ?? {};
        requireValue(typeof owner === "string" && /^[A-Za-z0-9:_-]{1,128}$/.test(owner));
        requireValue(typeof receipt === "string" && /^[0-9a-f]{40}$/.test(receipt));
        const ref = deletionRef(db, owner);
        await db.runTransaction(async tx => {
          const job = (await tx.get(ref)).data();
          if (job) {
            // A receipt resumes an already authorized job even after Auth deletion.
            const hash = digest(receipt);
            const receipts = job.receiptHashes ?? [];
            if (!receipts.includes(hash)) {
              requireValue(request.auth?.uid === owner && receipts.length < 10, "permission-denied");
              tx.update(ref, { receiptHashes: [...receipts, hash] });
            }
            return;
          }
          if (request.auth?.uid !== owner) {
            const user = await ignoreMissing(() => auth.getUser(owner));
            requireValue(!user, "permission-denied");
            return; // Completed job expired; no account exists any more.
          }
          requireValue(request.auth.token.firebase?.sign_in_provider !== "anonymous", "unauthenticated");
          tx.create(ref, { receiptHashes: [digest(receipt)], cleaned: false,
            blockedUntil: Timestamp.fromMillis(Date.now() + 2 * 3600_000) });
        });
        await processAccountDeletion(db, auth, owner);
        return { deleted: true };
      } catch (error) {
        if (error instanceof FriendError) throw new HttpsError(error.code, error.message);
        throw new HttpsError("unavailable", "account-deletion-retry");
      }
    }),
    eraseDeletedAccount: onDocumentCreated({ ...workerOptions, document: "accountDeletions/{uid}", retry: true },
      event => processAccountDeletion(db, auth, event.params.uid)),
    finishAccountDeletions: onSchedule({ ...workerOptions, schedule: "every 15 minutes", timeZone: "UTC", retryCount: 3 }, async () => {
      const [pending, expired] = await Promise.all([
        db.collection("accountDeletions").where("cleaned", "==", false).limit(20).get(),
        db.collection("accountDeletions").where("blockedUntil", "<=", Timestamp.now()).limit(20).get(),
      ]);
      const ids = [...new Set([...pending.docs, ...expired.docs].map(doc => doc.id))];
      const results = await Promise.allSettled(ids.map(uid => processAccountDeletion(db, auth, uid)));
      if (results.some(result => result.status === "rejected")) throw new Error("Account deletion needs retry");
    }),
  };
}
