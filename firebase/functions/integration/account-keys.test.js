import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { initializeTestEnvironment, assertFails } from "@firebase/rules-unit-testing";
import { initializeApp, deleteApp } from "firebase/app";
import { getAuth, connectAuthEmulator, signInWithCustomToken, createUserWithEmailAndPassword, signOut, signInWithEmailAndPassword } from "firebase/auth";
import { getFunctions, connectFunctionsEmulator, httpsCallable } from "firebase/functions";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { createHash } from "node:crypto";
import { initializeApp as adminApp, deleteApp as deleteAdminApp } from "firebase-admin/app";
import { getAuth as adminAuth } from "firebase-admin/auth";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
const admin = adminApp({ projectId: "demo-rudolstadt" }, "key-policy-tests");

const projectId = "demo-rudolstadt", edition = "rudolstadt-2026";
const apps = [];
let env;
const key = letter => "FF1-" + Array(8).fill(letter.repeat(4)).join("-");
const hash = key => createHash("sha256").update(key).digest("hex");
function device(name) {
  const app = initializeApp({ projectId, apiKey: "demo-api-key", appId: name }, `keys-${name}`); apps.push(app);
  const auth = getAuth(app); connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  const functions = getFunctions(app, "europe-west3"); connectFunctionsEmulator(functions, "127.0.0.1", 5001);
  return { auth, call: async (name, data = {}) => {
    const base = { protocol: 2, owner: auth.currentUser?.uid, sharing: { savedEvents: true, ratings: true }, edition, ...data };
    if (name === "publishFriendProfile") await httpsCallable(functions, "setFriendIdentity")({ protocol: 2, owner: auth.currentUser.uid, identity: { name: data.profile.name, hue: data.profile.hue } });
    return (await httpsCallable(functions, name)(base)).data;
  } };
}
before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { host: "127.0.0.1", port: 8080,
    rules: await readFile(new URL("../../firestore.rules", import.meta.url), "utf8") } });
});
after(async () => { await env?.cleanup(); await Promise.all(apps.map(deleteApp)); await deleteAdminApp(admin); });

test("a secret restores the same private profile on another device without exposing credential records", async () => {
  const first = device("first"), second = device("second"), stranger = device("stranger");
  const created = await first.call("createKeyAccount", { key: key("A"), uid: "spoofed" });
  const repeated = await first.call("createKeyAccount", { key: key("A") });
  assert.equal(repeated.uid, created.uid);
  assert.notEqual(created.uid, "spoofed");
  assert.equal(created.uid.includes("AAAA"), false);
  await signInWithCustomToken(first.auth, created.token);
  assert.equal(first.auth.currentUser.uid, created.uid);
  assert.equal(first.auth.currentUser.isAnonymous, false);
  await first.call("syncOwnProfile", { edition, owner: created.uid, records: [{ key: "note:7",
    version: { modifiedAt: 10, changeID: "device-one" }, value: { kind: "note", id: 7, noteText: "PRIVATE NOTE" } }] });
  await assert.rejects(stranger.call("signInWithAccountKey", { key: key("B") }), e => e.code === "functions/unauthenticated");
  const login = await second.call("signInWithAccountKey", { key: key("A").toLowerCase().replaceAll("-", " ") });
  await signInWithCustomToken(second.auth, login.token);
  assert.equal(second.auth.currentUser.uid, created.uid);
  const ownDB = env.authenticatedContext(created.uid).firestore();
  assert.equal((await getDoc(doc(ownDB, `users/${created.uid}/profileEditions/${edition}/records/note:7`))).data().value.noteText, "PRIVATE NOTE");
  for (const [collection, id] of [["accountKeySecrets", hash(key("A"))], ["accountKeyOwners", created.uid]]) {
    await assertFails(getDoc(doc(ownDB, collection, id)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), collection, id)));
  }
  assert.deepEqual(await first.call("accountKeyStatus", { owner: created.uid }), { eligible: true, hasKey: true, version: 1 });
  await assert.rejects(first.call("accountKeyStatus", { owner: "someone-else" }), e => e.code === "functions/permission-denied");
  await assert.rejects(first.call("createKeyAccount", { key: key("C") }), e => e.code === "functions/failed-precondition");
  await first.call("publishFriendProfile", { edition, profile: { name: "Key User", hue: 30, savedEventIDs: [], artistPreferences: [] } });
  assert.ok((await first.call("createFriendInvite", { edition })).token);
});

test("provider accounts cannot add keys, and legacy supplemental keys cannot sign in or bypass the restriction through account creation", async () => {
  const owner = device("email"), other = device("other");
  await createUserWithEmailAndPassword(owner.auth, "key-owner@example.org", "emulator-only-password");
  const uid = owner.auth.currentUser.uid;
  await owner.call("syncOwnProfile", { edition, owner: uid, records: [{ key: "note:7", version: { modifiedAt: 11, changeID: "before-key" }, value: { kind: "note", id: 7, noteText: "KEPT PRIVATE NOTE" } }] });
  assert.deepEqual(await owner.call("accountKeyStatus", { owner: uid }), { eligible: false, hasKey: false, version: 0 });
  await assert.rejects(owner.call("replaceAccountKey", { owner: uid, key: key("C"), expectedVersion: 0 }), e => e.code === "functions/failed-precondition");
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), "accountKeyOwners", uid), { hash: hash(key("C")), version: 1 });
    await setDoc(doc(context.firestore(), "accountKeySecrets", hash(key("C"))), { uid });
  });
  await assert.rejects(other.call("signInWithAccountKey", { key: key("C") }), e => e.code === "functions/unauthenticated");
  await assert.rejects(other.call("createKeyAccount", { key: key("C") }), e => e.code === "functions/unauthenticated");
  const ownDB = env.authenticatedContext(uid).firestore();
  assert.equal((await getDoc(doc(ownDB, `users/${uid}/profileEditions/${edition}/records/note:7`))).data().value.noteText, "KEPT PRIVATE NOTE");
  assert.equal(owner.auth.currentUser.uid, uid);
});

test("a provider account cannot bypass eligibility with a key-looking UID or forged marker", async () => {
  const uid = "key_XXXXXXXXXXXXXXXXXXXXXXXX";
  await adminAuth(admin).createUser({ uid, email: "key-prefix@example.org", password: "emulator-only-password" });
  const owner = device("prefix-provider"), other = device("prefix-stranger");
  await signInWithEmailAndPassword(owner.auth, "key-prefix@example.org", "emulator-only-password");
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), "accountKeyOwners", uid), { hash: hash(key("H")), version: 1, kind: "standalone" });
    await setDoc(doc(context.firestore(), "accountKeySecrets", hash(key("H"))), { uid });
  });
  assert.deepEqual(await owner.call("accountKeyStatus", { owner: uid }), { eligible: false, hasKey: false, version: 0 });
  await assert.rejects(owner.call("replaceAccountKey", { owner: uid, key: key("J"), expectedVersion: 1 }), e => e.code === "functions/failed-precondition");
  await assert.rejects(other.call("signInWithAccountKey", { key: key("H") }), e => e.code === "functions/unauthenticated");
});

test("a standalone account retains its identity and data when rotating its only sign-in method", async () => {
  const owner = device("rotation"), other = device("rotation-second");
  const created = await owner.call("createKeyAccount", { key: key("K") });
  await signInWithCustomToken(owner.auth, created.token);
  const uid = created.uid;
  await owner.call("syncOwnProfile", { edition, owner: uid, records: [{ key: "note:7", version: { modifiedAt: 12, changeID: "standalone-note" }, value: { kind: "note", id: 7, noteText: "KEEP STANDALONE NOTE" } }] });
  assert.equal((await owner.call("replaceAccountKey", { owner: uid, key: key("M"), expectedVersion: 1 })).version, 2);
  assert.equal((await owner.call("replaceAccountKey", { owner: uid, key: key("M"), expectedVersion: 1 })).version, 2);
  await assert.rejects(other.call("signInWithAccountKey", { key: key("K") }), e => e.code === "functions/unauthenticated");
  const login = await other.call("signInWithAccountKey", { key: key("M") });
  await signInWithCustomToken(other.auth, login.token);
  assert.equal(other.auth.currentUser.uid, uid);
  const ownDB = env.authenticatedContext(uid).firestore();
  assert.equal((await getDoc(doc(ownDB, `users/${uid}/profileEditions/${edition}/records/note:7`))).data().value.noteText, "KEEP STANDALONE NOTE");
});

test("the callable rejects excessive replacements without changing the working key", async () => {
  const owner = device("limited"), second = device("limited-second");
  const created = await owner.call("createKeyAccount", { key: key("F") });
  await signInWithCustomToken(owner.auth, created.token);
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), "accountKeyLimits", hash(`replace:${created.uid}`)), { count: 20, startedAt: Date.now() });
  });
  await assert.rejects(owner.call("replaceAccountKey", { owner: created.uid, key: key("G"), expectedVersion: 1 }), e => e.code === "functions/resource-exhausted");
  const login = await second.call("signInWithAccountKey", { key: key("F") });
  await signInWithCustomToken(second.auth, login.token);
  assert.equal(second.auth.currentUser.uid, created.uid);
  assert.deepEqual(await owner.call("accountKeyStatus", { owner: created.uid }), { eligible: true, hasKey: true, version: 1 });
});
