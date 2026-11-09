import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { initializeApp, deleteApp } from "firebase/app";
import { getAuth, connectAuthEmulator, createUserWithEmailAndPassword } from "firebase/auth";
import { getFunctions, connectFunctionsEmulator, httpsCallable } from "firebase/functions";
import { doc, getDoc, getDocs, setDoc, collection } from "firebase/firestore";

const projectId = "demo-rudolstadt", edition = "rudolstadt-2026";
const apps = [];
let env, owner, friend;
const record = (key, value, date, id = "device-a") => ({ key, value, version: { modifiedAt: date, changeID: id } });
const note = (text, date, id) => record("note:7", { kind: "note", id: 7, noteText: text }, date, id);
const path = (uid, key) => `users/${uid}/profileEditions/${edition}/records/${key}`;
async function account(name) {
  const app = initializeApp({ projectId, apiKey: "demo-api-key", appId: `owner-${name}` }, `owner-${name}`);
  apps.push(app);
  const auth = getAuth(app); connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  const { user } = await createUserWithEmailAndPassword(auth, `owner-${name}-${Date.now()}@example.org`, "emulator-only-password");
  const functions = getFunctions(app, "europe-west3"); connectFunctionsEmulator(functions, "127.0.0.1", 5001);
  return { uid: user.uid, call: async (name, data = {}) => {
    if (name === "publishFriendProfile") await httpsCallable(functions, "setFriendIdentity")({ protocol: 2, owner: user.uid, identity: { name: data.profile.name, hue: data.profile.hue } });
    return (await httpsCallable(functions, name)({ edition, protocol: 2, owner: user.uid, sharing: { savedEvents: true, ratings: true }, ...data })).data;
  } };
}
before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: { host: "127.0.0.1", port: 8080,
    rules: await readFile(new URL("../../firestore.rules", import.meta.url), "utf8") } });
  [owner, friend] = await Promise.all([account("alice"), account("bob")]);
});
after(async () => { await env?.cleanup(); await Promise.all(apps.map(deleteApp)); });

test("private sync keeps notes and version history inaccessible even to an accepted friend", async () => {
  const ownDB = env.authenticatedContext(owner.uid).firestore();
  const friendDB = env.authenticatedContext(friend.uid).firestore();
  const guestDB = env.unauthenticatedContext().firestore();
  const publicProfile = name => ({ name, hue: 30, savedEventIDs: [42], artistPreferences: [] });
  await owner.call("publishFriendProfile", { profile: publicProfile("Owner") });
  await friend.call("publishFriendProfile", { profile: publicProfile("Friend") });
  const invite = await owner.call("createFriendInvite", {});
  await friend.call("acceptFriendInvite", { token: invite.token });
  await assertSucceeds(getDoc(doc(friendDB, `friendProfileEditions/${edition}/profiles/${owner.uid}/categories/savedEvents`)));

  const text = "PRIVATE MULTILINE 😀\n".repeat(5000);
  await assert.rejects(owner.call("syncOwnProfile", { owner: friend.uid, records: [note("WRONG ACCOUNT", 1)] }));
  await owner.call("syncOwnProfile", { uid: friend.uid, records: [note(text, 10), record("event:42", { kind: "event", id: 42, isSaved: true }, 10)] });
  assert.equal((await getDoc(doc(ownDB, path(owner.uid, "note:7")))).data().value.noteText, text);
  await assertFails(getDoc(doc(friendDB, path(owner.uid, "note:7"))));
  await assertFails(getDocs(collection(friendDB, `users/${owner.uid}/profileEditions/${edition}/records`)));
  await assertFails(getDocs(collection(friendDB, `users/${owner.uid}/profileEditions/${edition}/noteVersions`)));
  await assertFails(getDoc(doc(guestDB, path(owner.uid, "note:7"))));
  await assertFails(setDoc(doc(ownDB, path(owner.uid, "note:7")), note("unvalidated", 100)));
  assert.equal((await getDoc(doc(friendDB, path(friend.uid, "note:7")))).exists(), false);

  await Promise.all([
    owner.call("syncOwnProfile", { records: [note("FROM DEVICE A", 20, "device-a")] }),
    owner.call("syncOwnProfile", { records: [note("FROM DEVICE Z", 20, "device-z")] }),
  ]);
  assert.equal((await getDoc(doc(ownDB, path(owner.uid, "note:7")))).data().value.noteText, "FROM DEVICE Z");
  const history = (await getDocs(collection(ownDB, `users/${owner.uid}/profileEditions/${edition}/noteVersions`))).docs.map(d => d.data().value.noteText);
  assert.ok(history.includes(text) && history.includes("FROM DEVICE A") && history.includes("FROM DEVICE Z"));
  await owner.call("syncOwnProfile", { records: [note("FROM DEVICE A", 20, "device-a")] });
  await owner.call("syncOwnProfile", { records: [note("FROM DEVICE A", 20, "device-a")] });
  assert.equal((await getDocs(collection(ownDB, `users/${owner.uid}/profileEditions/${edition}/noteVersions`))).size, history.length);

  await owner.call("syncOwnProfile", { records: [note("", 30), record("event:42", { kind: "event", id: 42, isSaved: false }, 30)] });
  await owner.call("syncOwnProfile", { records: [note("STALE OFFLINE NOTE", 5), record("event:42", { kind: "event", id: 42, isSaved: true }, 5)] });
  assert.equal((await getDoc(doc(ownDB, path(owner.uid, "note:7")))).data().value.noteText, "");
  assert.equal((await getDoc(doc(ownDB, path(owner.uid, "event:42")))).data().value.isSaved, false);
  const publicData = (await getDoc(doc(friendDB, `friendProfileEditions/${edition}/profiles/${owner.uid}/categories/savedEvents`))).data();
  assert.equal(publicData.artistNotes, undefined);
  assert.equal(JSON.stringify(publicData).includes("PRIVATE"), false);
});

test("archive edits update friends atomically while preserving previously shared data", async () => {
  const archive = "rudolstadt-2025";
  const [editor, viewer] = await Promise.all([account("archive-editor"), account("archive-viewer")]);
  const friendDB = env.authenticatedContext(viewer.uid).firestore();
  const ownDB = env.authenticatedContext(editor.uid).firestore();
  const shared = (category, year = archive) =>
    doc(friendDB, `friendProfileEditions/${year}/profiles/${editor.uid}/categories/${category}`);
  const previous = {
    name: "Archive Editor", hue: 30, savedEventIDs: [42, 43],
    artistPreferences: [{ artistID: 7, rating: 3 }],
  };
  await editor.call("publishFriendProfile", { edition: archive, profile: previous });
  await editor.call("publishFriendProfile", { profile: { ...previous, savedEventIDs: [99] } });
  await viewer.call("setFriendIdentity", { identity: { name: "Archive Viewer", hue: 30 } });
  const invite = await editor.call("createFriendInvite", {});
  await viewer.call("acceptFriendInvite", { token: invite.token });

  const archiveSync = records => editor.call("syncOwnProfile", { edition: archive, archiveSharing: true, records });
  const initial = await archiveSync([]);
  assert.equal(initial.archiveSharing, true);
  assert.deepEqual(initial.records.map(value => value.key), ["event:42", "event:43", "rating:7"]);
  assert.equal((await getDocs(collection(ownDB, `users/${editor.uid}/profileEditions/${archive}/records`))).size, 0);

  const event = (id, isSaved, date) => record(`event:${id}`, { kind: "event", id, isSaved }, date);
  const rating = (id, value, date) => record(`rating:${id}`, { kind: "rating", id, rating: value }, date);
  await Promise.all([
    archiveSync([event(42, false, 20), rating(7, 0, 20)]),
    archiveSync([event(44, true, 20), rating(8, 2, 20)]),
  ]);
  await archiveSync([event(42, true, 10), rating(7, 3, 10)]);
  await editor.call("publishFriendProfile", { edition: archive, profile: previous });
  // A device that still treats this year as current uses the old sync request.
  await editor.call("syncOwnProfile", { edition: archive, records: [event(45, true, 30)] });
  assert.deepEqual((await getDoc(shared("savedEvents"))).data(), { savedEventIDs: [43, 44, 45] });
  assert.deepEqual((await getDoc(shared("ratings"))).data(), {
    artistPreferences: [{ artistID: 8, rating: 2, iconName: null }],
  });
  assert.deepEqual((await getDoc(shared("savedEvents", edition))).data(), { savedEventIDs: [99] });
  assert.equal((await getDoc(doc(ownDB, `users/${editor.uid}/profileEditions/${archive}/records/event:42`))).data().value.isSaved, false);
});
