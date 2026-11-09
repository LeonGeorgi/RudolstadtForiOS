import { createHash, randomBytes } from "node:crypto";
import { Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FriendError, requireValue } from "./protocol.js";
import { requireLiveAccount } from "./account-deletion.js";

export function normalizeAccountKey(value) {
  requireValue(typeof value === "string" && value.length <= 128, "unauthenticated");
  const compact = value.replace(/[\s-]/g, "").toUpperCase();
  requireValue(/^FF1[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{32}$/.test(compact), "unauthenticated");
  return `FF1-${compact.slice(3).match(/.{4}/g).join("-")}`;
}

export const accountKeyHash = value => createHash("sha256").update(normalizeAccountKey(value)).digest("hex");

export function standaloneKeyOwner(uid, value) {
  return /^key_[A-Za-z0-9_-]{24}$/.test(uid) && value != null &&
    (value.kind === "standalone" || value.kind === undefined);
}
export function standaloneKeyUser(user) {
  return !user.disabled && !user.email && !user.phoneNumber && user.providerData.every(provider => provider.providerId === "firebase");
}

// Stable bucket IDs bound storage growth. No raw IPs, keys or tokens are persisted in limits.
export async function keyRateLimit(db, operation, identity, limit, now = Date.now()) {
  const id = createHash("sha256").update(`${operation}:${identity}`).digest("hex");
  const ref = db.collection("accountKeyLimits").doc(id);
  await db.runTransaction(async tx => {
    if (operation === "replace") await requireLiveAccount(tx, db, identity);
    const value = (await tx.get(ref)).data();
    const fresh = value && now >= value.startedAt && now - value.startedAt < 3600_000;
    const count = fresh ? value.count : 0;
    requireValue(count < limit, "resource-exhausted");
    tx.set(ref, { count: count + 1, startedAt: fresh ? value.startedAt : now });
  });
}

export async function createKeyOwner(db, key) {
  const hash = accountKeyHash(key);
  const ref = db.collection("accountKeySecrets").doc(hash);
  return db.runTransaction(async tx => {
    const existing = (await tx.get(ref)).data();
    if (existing) {
      await requireLiveAccount(tx, db, existing.uid);
      return existing.uid; // An interrupted creation can safely retry the same secret.
    }
    const uid = `key_${randomBytes(18).toString("base64url")}`;
    tx.create(ref, { uid });
    tx.create(db.collection("accountKeyOwners").doc(uid), { hash, kind: "standalone", version: 1, changedAt: Timestamp.now() });
    return uid;
  });
}

export async function replaceOwnerKey(db, uid, key, expectedVersion) {
  const hash = accountKeyHash(key);
  requireValue(Number.isSafeInteger(expectedVersion) && expectedVersion >= 0);
  const owner = db.collection("accountKeyOwners").doc(uid);
  const secret = db.collection("accountKeySecrets").doc(hash);
  return db.runTransaction(async tx => {
    await requireLiveAccount(tx, db, uid);
    const [before, collision] = await Promise.all([tx.get(owner), tx.get(secret)]);
    const value = before.data();
    requireValue(standaloneKeyOwner(uid, value), "failed-precondition", "key-account-required");
    requireValue(!collision.exists || collision.get("uid") === uid, "already-exists");
    if (value?.hash === hash) return value.version;
    requireValue((value?.version ?? 0) === expectedVersion, "failed-precondition", "key-changed");
    if (value?.hash) tx.delete(db.collection("accountKeySecrets").doc(value.hash));
    const version = (value?.version ?? 0) + 1;
    tx.set(secret, { uid });
    tx.set(owner, { hash, kind: "standalone", version, changedAt: Timestamp.now() });
    return version;
  });
}

export function accountKeyFunctions(db, auth, options) {
  const eligible = async (uid, allowUncreated = false) => {
    const value = (await db.collection("accountKeyOwners").doc(uid).get()).data();
    if (!standaloneKeyOwner(uid, value)) return false;
    try {
      const user = await auth.getUser(uid);
      return standaloneKeyUser(user);
    } catch (error) {
      if (error.code === "auth/user-not-found") return allowUncreated;
      throw error;
    }
  };
  const handler = (operation, limit, authenticated, run) => onCall(options, async request => {
    try {
      if (authenticated) {
        requireValue(request.auth && request.auth.token.firebase?.sign_in_provider !== "anonymous", "unauthenticated");
        requireValue(request.data?.owner === request.auth.uid, "permission-denied");
      } else requireValue(!request.auth, "failed-precondition", "sign-out-first");
      if (limit) await keyRateLimit(db, operation, authenticated ? request.auth.uid : (request.rawRequest.ip ?? "unknown"), limit);
      return await run(request);
    } catch (error) {
      if (error instanceof FriendError) throw new HttpsError(error.code, error.message);
      throw error;
    }
  });
  const token = async uid => {
    try { return await auth.createCustomToken(uid); }
    catch (error) {
      const configuration = /signBlob|iam\.|permission|credential|service account/i.test(error.message ?? "");
      throw new HttpsError(configuration ? "failed-precondition" : "unavailable", "key-token-unavailable",
        configuration ? { reason: "key-auth-configuration" } : undefined);
    }
  };
  return {
    createKeyAccount: handler("create", 300, false, async request => {
      const uid = await createKeyOwner(db, request.data?.key);
      requireValue(await eligible(uid, true), "unauthenticated");
      return { uid, token: await token(uid) };
    }),
    signInWithAccountKey: handler("login", 1800, false, async request => {
      const hash = accountKeyHash(request.data?.key);
      const value = (await db.collection("accountKeySecrets").doc(hash).get()).data();
      requireValue(value?.uid, "unauthenticated");
      requireValue(await eligible(value.uid), "unauthenticated");
      requireValue(!(await db.collection("accountDeletions").doc(value.uid).get()).exists, "unauthenticated");
      return { uid: value.uid, token: await token(value.uid) };
    }),
    accountKeyStatus: handler("status", 0, true, async request => {
      const value = (await db.collection("accountKeyOwners").doc(request.auth.uid).get()).data();
      const allowed = await eligible(request.auth.uid);
      return { eligible: allowed, hasKey: allowed && !!value, version: allowed ? value.version : 0 };
    }),
    replaceAccountKey: handler("replace", 20, true, async request => {
      requireValue(await eligible(request.auth.uid), "failed-precondition", "key-account-required");
      return { version: await replaceOwnerKey(db, request.auth.uid, request.data?.key, request.data?.expectedVersion) };
    }),
  };
}
