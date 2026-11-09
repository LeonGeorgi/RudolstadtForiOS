import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { initializeApp, deleteApp } from "firebase/app";
import { getAuth, connectAuthEmulator, createUserWithEmailAndPassword } from "firebase/auth";
import { getFunctions, connectFunctionsEmulator, httpsCallable } from "firebase/functions";
import { doc, getDoc, getDocFromServer, getDocs, setDoc, collection, onSnapshot, query, where } from "firebase/firestore";

const projectId = "demo-rudolstadt", edition = "rudolstadt-2026", second = "other-festival-2027";
const all = { savedEvents: true, ratings: true, notes: false }, none = { savedEvents: false, ratings: false, notes: false };
const payload = id => ({ savedEventIDs: [id], artistPreferences: [{ artistID: id, rating: 3 }], artistNotes: ["PRIVATE"], email: "PRIVATE" });
const apps = []; let env, alice, bob, carol;
async function account(name) {
  const app = initializeApp({ projectId, apiKey: "demo-api-key", appId: `global-${name}` }, `global-${name}`); apps.push(app);
  const auth = getAuth(app); connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  const { user } = await createUserWithEmailAndPassword(auth, `global-${name}@example.org`, "emulator-only-password");
  const functions = getFunctions(app, "europe-west3"); connectFunctionsEmulator(functions, "127.0.0.1", 5001);
  const d = { uid: user.uid, call: async (name, data = {}) => (await httpsCallable(functions, name)({ protocol: 2, owner: user.uid, ...data })).data };
  await d.call("setFriendIdentity", { identity: { name, hue: 30 } });
  return d;
}
const category = (owner, kind, year = edition) => `friendProfileEditions/${year}/profiles/${owner}/categories/${kind}`;
const edge = (owner, other) => `friendships/${owner}/friends/${other}`;
before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { host: "127.0.0.1", port: 8080, rules: await readFile(new URL("../../firestore.rules", import.meta.url), "utf8") } });
  await env.clearFirestore();
  [alice, bob, carol] = await Promise.all([account("alice"), account("bob"), account("carol")]);
});
after(async () => { await env?.cleanup(); await Promise.all(apps.map(deleteApp)); });

function watchDenial(database, path) {
  let ready, denied;
  const loaded = new Promise(resolve => { ready = resolve; });
  const revoked = new Promise(resolve => { denied = resolve; });
  const stop = onSnapshot(doc(database, path), { includeMetadataChanges: true }, snapshot => {
    if (snapshot.exists() && !snapshot.metadata.fromCache) ready();
  }, denied);
  return { loaded, revoked, stop };
}

test("one friendship spans festivals while each direction has independent field permissions", { timeout: 60_000 }, async () => {
  const aliceDB = env.authenticatedContext(alice.uid).firestore(), bobDB = env.authenticatedContext(bob.uid).firestore(), carolDB = env.authenticatedContext(carol.uid).firestore();
  for (const year of [edition, second]) {
    await alice.call("publishFriendProfile", { edition: year, profile: payload(year === edition ? 42 : 77) });
    await bob.call("publishFriendProfile", { edition: year, profile: payload(99) });
  }
  await assertFails(getDoc(doc(bobDB, category(alice.uid, "savedEvents"))));
  await assertFails(getDoc(doc(bobDB, `friendIdentities/${alice.uid}`)));
  const invite = await alice.call("createFriendInvite", { sharing: { savedEvents: true, ratings: false, notes: false } });
  assert.deepEqual(await bob.call("previewFriendInvite", { token: invite.token }), { name: "alice", sharing: { savedEvents: true, ratings: false, notes: false } });
  await bob.call("acceptFriendInvite", { token: invite.token, sharing: { savedEvents: false, ratings: true, notes: false } });
  for (const year of [edition, second]) {
    assert.ok((await getDoc(doc(bobDB, category(alice.uid, "savedEvents", year)))).data().savedEventIDs.length);
    await assertFails(getDoc(doc(bobDB, category(alice.uid, "ratings", year))));
    await assertFails(getDoc(doc(aliceDB, category(bob.uid, "savedEvents", year))));
    assert.equal((await getDoc(doc(aliceDB, category(bob.uid, "ratings", year)))).data().artistPreferences[0].artistID, 99);
    await assertFails(getDoc(doc(carolDB, category(alice.uid, "savedEvents", year))));
  }
  assert.equal((await getDoc(doc(bobDB, `friendIdentities/${alice.uid}`))).data().name, "alice");
  await assertFails(getDocs(collection(bobDB, "friendIdentities")));
  await assertFails(getDocs(collection(bobDB, `friendProfileEditions/${edition}/profiles/${alice.uid}/categories`)));
  await assertFails(setDoc(doc(aliceDB, edge(alice.uid, bob.uid)), { sharing: all }));
  await assertFails(getDocs(collection(bobDB, `friendships/${alice.uid}/friends`)));
  await assert.rejects(bob.call("updateFriendSharing", { owner: alice.uid, uid: bob.uid, sharing: all }), e => e.code === "functions/permission-denied");
  const stored = (await getDoc(doc(bobDB, category(alice.uid, "savedEvents")))).data();
  assert.deepEqual(Object.keys(stored), ["savedEventIDs"]);
  await assertFails(getDoc(doc(bobDB, `users/${alice.uid}/profileEditions/${edition}/records/note:7`)));
  await assertFails(getDoc(doc(bobDB, category(alice.uid, "notes"))));

  const watch = watchDenial(bobDB, category(alice.uid, "savedEvents"));
  await watch.loaded;
  await alice.call("updateFriendSharing", { uid: bob.uid, sharing: none });
  await alice.call("publishFriendProfile", { edition, profile: payload(43) });
  assert.equal((await watch.revoked).code, "permission-denied"); watch.stop();
  for (const year of [edition, second]) await assertFails(getDocFromServer(doc(bobDB, category(alice.uid, "savedEvents", year))));
  // Bob's independent outgoing setting is unchanged, and global identity remains readable.
  assert.deepEqual((await getDoc(doc(aliceDB, edge(alice.uid, bob.uid)))).data().receiving, { savedEvents: false, ratings: true, notes: false });
  await assertSucceeds(getDoc(doc(bobDB, `friendIdentities/${alice.uid}`)));
  await bob.call("removeFriend", { uid: alice.uid });
  await assertFails(getDocFromServer(doc(aliceDB, category(bob.uid, "ratings"))));
  await assertFails(getDocFromServer(doc(bobDB, `friendIdentities/${alice.uid}`)));
  assert.equal((await getDocFromServer(doc(aliceDB, edge(alice.uid, bob.uid)))).exists(), false);
});

test("default-deny invitations can connect without publishing any festival profile", async () => {
  const owner = await account("default-owner"), friend = await account("default-friend");
  const invite = await owner.call("createFriendInvite", { sharing: none });
  await friend.call("acceptFriendInvite", { token: invite.token, sharing: none });
  const friendDB = env.authenticatedContext(friend.uid).firestore();
  assert.equal((await getDoc(doc(friendDB, `friendIdentities/${owner.uid}`))).exists(), true);
  await owner.call("publishFriendProfile", { edition: "future-festival-2028", profile: payload(100) });
  await assertFails(getDoc(doc(friendDB, category(owner.uid, "savedEvents", "future-festival-2028"))));
  await owner.call("updateFriendSharing", { uid: friend.uid, sharing: { savedEvents: false, ratings: true, notes: false } });
  await assertSucceeds(getDocFromServer(doc(friendDB, category(owner.uid, "ratings", "future-festival-2028"))));
  await assertFails(getDocFromServer(doc(friendDB, category(owner.uid, "savedEvents", "future-festival-2028"))));
});

test("one-time consumption is atomic and accepting an existing friend never resets either grant", async () => {
  const owner = await account("race-owner"), a = await account("race-a"), b = await account("race-b");
  const invite = await owner.call("createFriendInvite", { sharing: none });
  const result = await Promise.allSettled([a.call("acceptFriendInvite", { token: invite.token, sharing: all }), b.call("acceptFriendInvite", { token: invite.token, sharing: all })]);
  assert.equal(result.filter(x => x.status === "fulfilled").length, 1);
  const winner = result[0].status === "fulfilled" ? a : b;
  await owner.call("updateFriendSharing", { uid: winner.uid, sharing: { savedEvents: true, ratings: false, notes: false } });
  // Reset only the emulator cooldown to create a second invitation immediately.
  await env.withSecurityRulesDisabled(async ctx => { await setDoc(doc(ctx.firestore(), `friendships/${owner.uid}`), { lastInviteAt: new Date(0) }, { merge: true }); });
  const repeated = await owner.call("createFriendInvite", { sharing: all });
  await winner.call("acceptFriendInvite", { token: repeated.token, sharing: none });
  const ownDB = env.authenticatedContext(owner.uid).firestore();
  const connection = (await getDoc(doc(ownDB, edge(owner.uid, winner.uid)))).data();
  assert.deepEqual(connection.sharing, { savedEvents: true, ratings: false, notes: false });
  assert.deepEqual(connection.receiving, all);
});

test("legacy friendships and invitations grant no global access; malformed and expired invites fail", async () => {
  const token = "z".repeat(43), id = createHash("sha256").update(token).digest("hex");
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), `friendEditions/${edition}/members/${alice.uid}/friends/${carol.uid}`), { uid: carol.uid });
    await setDoc(doc(ctx.firestore(), `friendEditions/${edition}/profiles/${carol.uid}`), { ...payload(42), name: "Old friend" });
    await setDoc(doc(ctx.firestore(), `friendInvites/${id}`), { owner: alice.uid, edition, expiresAt: new Date(Date.now() + 86400_000) });
  });
  const db = env.authenticatedContext(alice.uid).firestore();
  await assertFails(getDoc(doc(db, `friendEditions/${edition}/profiles/${carol.uid}`)));
  await assertFails(getDoc(doc(db, `friendIdentities/${carol.uid}`)));
  await assert.rejects(carol.call("acceptFriendInvite", { token, sharing: all }));
  await env.withSecurityRulesDisabled(async ctx => { await setDoc(doc(ctx.firestore(), `friendInvitesV2/${id}`), { version: 2, owner: alice.uid, sharing: all, expiresAt: new Date(0) }); });
  await assert.rejects(carol.call("acceptFriendInvite", { token, sharing: all }));
  await assert.rejects(alice.call("acceptFriendInvite", { token, sharing: all }));
  await assert.rejects(alice.call("createFriendInvite", { sharing: { savedEvents: "yes", ratings: true } }));
  await assert.rejects(alice.call("publishFriendProfile", { protocol: 1, edition, profile: payload(42) }), e => e.code === "functions/failed-precondition");
});


test("notes require explicit per-friend permission across festivals while history and all other private fields stay private", { timeout: 60_000 }, async () => {
  const owner = await account("notes-owner"), friend = await account("notes-friend"), stranger = await account("notes-stranger");
  const text = "Personal multiline note 😀\n".repeat(4000);
  for (const year of [edition, second]) await owner.call("syncOwnProfile", { edition: year, records: [
    { key: "note:7", version: { modifiedAt: 10, changeID: "note-first" }, value: { kind: "note", id: 7, noteText: text } },
    { key: "event:42", version: { modifiedAt: 10, changeID: "private-event" }, value: { kind: "event", id: 42, isSaved: true } },
  ] });
  const invite = await owner.call("createFriendInvite", { sharing: none });
  await friend.call("acceptFriendInvite", { token: invite.token, sharing: none });
  const db = env.authenticatedContext(friend.uid).firestore(), unknown = env.authenticatedContext(stranger.uid).firestore();
  const records = year => collection(db, `users/${owner.uid}/profileEditions/${year}/records`);
  await assertFails(getDoc(doc(db, `users/${owner.uid}/profileEditions/${edition}/records/note:7`)));
  await assertFails(getDocs(query(records(edition), where("value.kind", "==", "note"))));
  await owner.call("updateFriendSharing", { uid: friend.uid, sharing: { savedEvents: false, ratings: false, notes: true } });
  for (const year of [edition, second]) {
    const notes = await getDocs(query(records(year), where("value.kind", "==", "note")));
    assert.equal(notes.size, 1); assert.equal(notes.docs[0].data().value.noteText, text);
    await assertFails(getDocs(records(year)));
    await assertFails(getDoc(doc(db, `users/${owner.uid}/profileEditions/${year}/records/event:42`)));
    await assertFails(getDocs(collection(db, `users/${owner.uid}/profileEditions/${year}/noteVersions`)));
    await assertFails(getDoc(doc(unknown, `users/${owner.uid}/profileEditions/${year}/records/note:7`)));
  }
  await owner.call("syncOwnProfile", { edition, records: [{ key: "note:7", version: { modifiedAt: 20, changeID: "note-new" }, value: { kind: "note", id: 7, noteText: "NEW CURRENT NOTE" } }] });
  assert.equal((await getDocFromServer(doc(db, `users/${owner.uid}/profileEditions/${edition}/records/note:7`))).data().value.noteText, "NEW CURRENT NOTE");
  const ownDB = env.authenticatedContext(owner.uid).firestore();
  const history = await getDocs(collection(ownDB, `users/${owner.uid}/profileEditions/${edition}/noteVersions`));
  assert.ok(history.size >= 2);
  for (const row of history.docs) await assertFails(getDoc(doc(db, row.ref.path)));
  const watch = watchDenial(db, `users/${owner.uid}/profileEditions/${edition}/records/note:7`);
  await watch.loaded;
  await owner.call("updateFriendSharing", { uid: friend.uid, sharing: none });
  await owner.call("syncOwnProfile", { edition, records: [{ key: "note:7", version: { modifiedAt: 30, changeID: "note-private-again" }, value: { kind: "note", id: 7, noteText: "PRIVATE AGAIN" } }] });
  assert.equal((await watch.revoked).code, "permission-denied"); watch.stop();
  for (const year of [edition, second]) await assertFails(getDocs(query(records(year), where("value.kind", "==", "note"))));
});
