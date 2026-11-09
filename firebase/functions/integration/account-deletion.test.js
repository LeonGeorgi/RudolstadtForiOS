import { test, after } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { initializeApp, deleteApp } from "firebase/app";
import { getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithCustomToken } from "firebase/auth";
import { getFunctions, connectFunctionsEmulator, httpsCallable } from "firebase/functions";
import { initializeApp as adminApp, deleteApp as deleteAdminApp } from "firebase-admin/app";
import { getAuth as adminAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { processAccountDeletion, deletionRef } from "../src/account-deletion.js";

process.env.GCLOUD_PROJECT = "demo-rudolstadt";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
const admin = adminApp({ projectId: "demo-rudolstadt" }, "deletion-tests");
const db = getFirestore(admin), auth = adminAuth(admin), apps = [];
const edition = "rudolstadt-2026", otherEdition = "rudolstadt-2027";
const key = "FF1-" + Array(8).fill("PPPP").join("-");
const hash = value => createHash("sha256").update(value).digest("hex");
const badge = name => ({ name, hue: 30, savedEventIDs: [42], artistPreferences: [] });
const note = text => [{ key: "note:7", version: { modifiedAt: 10, changeID: "delete-test" }, value: { kind: "note", id: 7, noteText: text } }];
function device(name) {
  const app = initializeApp({ projectId: "demo-rudolstadt", apiKey: "demo-api-key", appId: name }, `deletion-${name}`); apps.push(app);
  const auth = getAuth(app); connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  const functions = getFunctions(app, "europe-west3"); connectFunctionsEmulator(functions, "127.0.0.1", 5001);
  return { auth, call: async (name, data = {}) => {
    const base = { protocol: 2, owner: auth.currentUser?.uid, sharing: { savedEvents: true, ratings: true }, edition, ...data };
    if (name === "publishFriendProfile") await httpsCallable(functions, "setFriendIdentity")({ protocol: 2, owner: auth.currentUser.uid, identity: { name: data.profile.name, hue: data.profile.hue } });
    return (await httpsCallable(functions, name)(base)).data;
  } };
}
async function account(name) {
  const d = device(name);
  await createUserWithEmailAndPassword(d.auth, `deletion-${name}@example.org`, "emulator-only-password");
  d.uid = d.auth.currentUser.uid;
  return d;
}
after(async () => { await Promise.all(apps.map(deleteApp)); await deleteAdminApp(admin); });

test("deletion erases every edition, note history, incoming and outgoing friendships, invites and keys without touching another account", { timeout: 90_000 }, async () => {
  const owner = device("owner"), friend = await account("friend"), guest = device("guest");
  const created = await owner.call("createKeyAccount", { key });
  await signInWithCustomToken(owner.auth, created.token);
  owner.uid = created.uid;
  await owner.call("syncOwnProfile", { owner: owner.uid, records: note("PRIVATE OWNER NOTE") });
  await owner.call("syncOwnProfile", { edition: otherEdition, owner: owner.uid, records: note("OTHER YEAR NOTE") });
  await friend.call("syncOwnProfile", { owner: friend.uid, records: note("KEEP FRIEND NOTE") });
  await owner.call("publishFriendProfile", { profile: badge("Owner") });
  await friend.call("publishFriendProfile", { profile: badge("Friend") });
  const invite = await owner.call("createFriendInvite");
  await friend.call("acceptFriendInvite", { token: invite.token });
  // Keep a pre-deletion custom token to simulate a delayed exchange on another device.
  const oldLogin = await guest.call("signInWithAccountKey", { key });
  const receipt = "ab".repeat(20);
  const incoming = db.doc(`friendEditions/${otherEdition}/members/${friend.uid}/friends/${owner.uid}`);
  await incoming.set({ uid: owner.uid });
  await db.doc(`friendEditions/${otherEdition}/profiles/${owner.uid}`).set(badge("Old edition"));
  await db.doc("friendInvites/used-by-deleted-user").set({ owner: friend.uid, usedBy: owner.uid });
  await db.doc("friendInvites/expired-deleted-owner").set({ owner: owner.uid, expiresAt: Timestamp.fromMillis(0), revoked: true });
  await db.doc("friendInvites/keep-other-invitation").set({ owner: friend.uid });
  await assert.rejects(friend.call("deleteAccount", { owner: owner.uid, receipt }), e => e.code === "functions/permission-denied");
  assert.deepEqual(await owner.call("deleteAccount", { owner: owner.uid, receipt }), { deleted: true });
  await assert.rejects(auth.getUser(owner.uid), e => e.code === "auth/user-not-found");
  assert.equal((await db.doc(`users/${owner.uid}`).listCollections()).length, 0);
  for (const year of [edition, otherEdition]) {
    assert.equal((await db.doc(`friendEditions/${year}/profiles/${owner.uid}`).get()).exists, false);
    assert.equal((await db.doc(`friendEditions/${year}/members/${owner.uid}`).listCollections()).length, 0);
  }
  assert.equal((await db.collectionGroup("friends").where("uid", "==", owner.uid).get()).size, 0);
  assert.equal((await db.doc(`friendIdentities/${owner.uid}`).get()).exists, false);
  assert.equal((await db.doc(`friendships/${owner.uid}`).listCollections()).length, 0);
  assert.equal((await db.doc(`friendProfileEditions/${edition}/profiles/${owner.uid}`).listCollections()).length, 0);
  assert.equal((await db.collection("friendInvitesV2").where("owner", "==", owner.uid).get()).size, 0);
  assert.equal((await db.collection("friendInvitesV2").where("usedBy", "==", owner.uid).get()).size, 0);
  assert.equal((await db.collection("friendInvites").where("owner", "==", owner.uid).get()).size, 0);
  assert.equal((await db.collection("friendInvites").where("usedBy", "==", owner.uid).get()).size, 0);
  assert.equal((await db.collection("accountKeySecrets").where("uid", "==", owner.uid).get()).size, 0);
  assert.equal((await db.doc(`accountKeyOwners/${owner.uid}`).get()).exists, false);
  assert.equal((await db.doc(`accountKeyLimits/${hash(`replace:${owner.uid}`)}`).get()).exists, false);
  assert.equal((await db.doc(`users/${friend.uid}/profileEditions/${edition}/records/note:7`).get()).get("value.noteText"), "KEEP FRIEND NOTE");
  assert.equal((await db.doc("friendInvites/keep-other-invitation").get()).exists, true);
  await assert.rejects(guest.call("signInWithAccountKey", { key }), e => e.code === "functions/unauthenticated");
  await assert.rejects(guest.call("deleteAccount", { owner: owner.uid, receipt: "cd".repeat(20) }), e => e.code === "functions/permission-denied");
  assert.deepEqual(await guest.call("deleteAccount", { owner: owner.uid, receipt }), { deleted: true });
  const job = (await deletionRef(db, owner.uid).get()).data();
  assert.equal(JSON.stringify(job).includes(receipt), false);
  assert.equal(job.cleaned, true);
  // Firebase may recreate an Auth-only user when exchanging an earlier custom token.
  // The deletion fence must still prevent all writes until that token has expired.
  await signInWithCustomToken(guest.auth, oldLogin.token);
  await assert.rejects(guest.call("publishFriendProfile", { profile: badge("Must not return") }), e => e.code === "functions/permission-denied");
  await assert.rejects(guest.call("syncOwnProfile", { owner: owner.uid, records: note("Must not return") }), e => e.code === "functions/permission-denied");
  await assert.rejects(guest.call("replaceAccountKey", { owner: owner.uid, key, expectedVersion: 0 }), e => e.code === "functions/permission-denied");
  assert.deepEqual(await guest.call("accountDeletionStatus", { owner: owner.uid }), { deleted: true });
  await processAccountDeletion(db, auth, owner.uid, job.blockedUntil.toMillis() + 1);
  assert.equal((await deletionRef(db, owner.uid).get()).exists, false);
  await assert.rejects(auth.getUser(owner.uid), e => e.code === "auth/user-not-found");
});

test("a partially failed job resumes and deletes more than one write batch", { timeout: 90_000 }, async () => {
  const owner = await account("retry");
  const batch = db.batch();
  for (let i = 0; i < 310; i++) batch.set(db.doc(`friendEditions/${edition}/members/incoming-${i}/friends/${owner.uid}`), { uid: owner.uid });
  batch.set(db.doc(`users/${owner.uid}/profileEditions/${edition}/noteVersions/keep-until-retry`), { noteText: "RETRY NOTE" });
  await batch.commit();
  await deletionRef(db, owner.uid).set({ receiptHashes: [hash("ef".repeat(20))], cleaned: false, blockedUntil: Timestamp.fromMillis(Date.now() + 7200_000) });
  let fail = true;
  const faulty = new Proxy(db, { get(target, property) {
    if (property === "recursiveDelete") return async (...args) => { if (fail) { fail = false; throw Error("Injected partial failure"); } return target.recursiveDelete(...args); };
    const value = Reflect.get(target, property); return typeof value === "function" ? value.bind(target) : value;
  } });
  await assert.rejects(processAccountDeletion(faulty, auth, owner.uid));
  await processAccountDeletion(db, auth, owner.uid);
  assert.equal((await db.collectionGroup("friends").where("uid", "==", owner.uid).get()).empty, true);
  assert.equal((await db.doc(`users/${owner.uid}`).listCollections()).length, 0);
  await assert.rejects(auth.getUser(owner.uid), e => e.code === "auth/user-not-found");
});
