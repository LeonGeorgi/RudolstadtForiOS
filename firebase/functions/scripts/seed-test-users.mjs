// Development-only fixtures, using the same authenticated APIs as the apps.
import { randomBytes } from "node:crypto";
import { readFile, writeFile, mkdir, chmod, open, unlink, rename } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";
import { initializeApp, deleteApp } from "firebase/app";
import { getAuth, signInWithCustomToken, signOut } from "firebase/auth";
import { getFunctions, httpsCallable } from "firebase/functions";
import { getFirestore, getDocs, getDocFromServer, collection, doc, terminate } from "firebase/firestore";

const projectId = "festival-friends-dev", edition = "rudolstadt-2026";
const folder = new URL("../../.local/", import.meta.url);
const manifestFile = new URL("test-users.json", folder), reportFile = new URL("test-users.txt", folder);
const demoFile = new URL("festival-demo.txt", folder);
const lockFile = new URL("test-users.lock", folder);
const refresh = process.argv.includes("--refresh-invites");
assert.ok(process.argv.slice(2).every(value => value === "--refresh-invites"), "Unknown option");
const config = JSON.parse(await readFile(new URL("../../../androidApp/google-services.json", import.meta.url), "utf8"));
assert.equal(config.project_info.project_id, projectId, "Only festival-friends-dev is supported");
const sdk = { projectId, apiKey: config.client[0].api_key[0].current_key, appId: config.client[0].client_info.mobilesdk_app_id };

function newKey() {
  const alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
  const bits = [...randomBytes(20)].map(value => value.toString(2).padStart(8, "0")).join("");
  return "FF1-" + bits.match(/.{5}/g).map(value => alphabet[parseInt(value, 2)]).join("").match(/.{4}/g).join("-");
}
const defaultSharing = { savedEvents: true, ratings: true, notes: false };
const definitions = [
  { id: "anna", name: "Test · Anna", hue: 30, sharing: defaultSharing, saved: [0,1,2,4,5,8,9,10], rated: [0,1,2,3,4,5,6,7,8,9], ratings: [3,2,1,3,1,2,3,-1,1,2], notes: [[0, "Testnotiz: Mit Freunden vor der Bühne treffen."], [4, "Testnotiz:\nFrüh hingehen und einen Platz mit guter Sicht suchen.\nDanach gemeinsam etwas essen."]] },
  { id: "ben", name: "Test · Ben", hue: 255, sharing: defaultSharing, saved: [0,2,3,4,6,8,11,12,13,14], rated: [0,2,3,4,6,8,11,12], ratings: [1,3,-1,2,3,1,2,3], notes: [[2, "Private Testnotiz: Erst nach dem Essen zur Bühne gehen."], [6, "Private Testnotiz: Diesen Künstler später noch einmal anhören."], [11, "Private Testnotiz: Nicht an Freunde freigegeben."]] },
  { id: "clara", name: "Test · Clara", hue: 165, sharing: defaultSharing, saved: [1,4,5,7,8,10,15,16,17], rated: [1,3,4,5,7,8,10,15,17], ratings: [2,1,3,-1,2,3,1,2,3], notes: [[4, "Testnotiz: Besonders auf die Instrumente achten."], [8, "Testnotiz: Gemeinsamer Konzerttipp – danach Eindrücke austauschen."]] },
  { id: "david", name: "Test · David", hue: 75, sharing: defaultSharing, description: "Viele gemeinsame Konzerte und ähnliche Bewertungen", saved: [0,2,4,8,12,18,20,24,31,35,40,44], rated: [0,2,4,8,12,18,20,24,31,35,40,44,48,51], ratings: [3,2,3,3,2,3,1,3,2,3,3,2,3,1], notes: [[4,"Testnotiz: Hier treffen wir uns vor dem Konzert."],[31,"Testnotiz: Der Tipp für den gemeinsamen Abend."]] },
  { id: "emilia", name: "Test · Emilia", hue: 300, sharing: defaultSharing, description: "Teilweise andere Vorlieben und eigene Entdeckungen", saved: [1,4,9,16,22,28,34,41,46,52], rated: [0,1,4,8,9,16,22,28,34,41,46,52], ratings: [1,3,1,2,3,1,3,3,2,3,2,3], notes: [[22,"Private Testnotiz: Erst den Hörbeispielen eine Chance geben."],[41,"Private Testnotiz: Alternativprogramm für den Abend."]] },
  { id: "fatima", name: "Test · Fatima", hue: 345, sharing: defaultSharing, description: "Viele neue Konzerttipps außerhalb der eigenen Merkliste", saved: [0,4,8,19,23,26,32,38,43,47,53,57,60,63], rated: [4,8,19,23,26,32,38,43,47,53,57,60,63], ratings: [3,2,3,2,3,3,2,3,3,2,3,2,3], notes: [[19,"Testnotiz: Noch unbekannt, aber der erste Eindruck ist toll."],[38,"Testnotiz: Zeit für einen gemeinsamen Abstecher einplanen."],[57,"Testnotiz: Persönlicher Geheimtipp für den letzten Festivaltag."]] },
  { id: "jonas", name: "Test · Jonas", hue: 15, sharing: defaultSharing, description: "Teilt Konzertplanung und Bewertungen, behält Notizen für sich", saved: [0,3,4,8,11,14,18,25,30,36,42,49], rated: [0,3,4,8,11,14,18,25,30,36], ratings: [2,3,1,3,2,3,1,2,3,2], notes: [[11,"Private Testnotiz: Zwischen den Bühnen eine Pause lassen."],[25,"Private Testnotiz: Lieber etwas weiter hinten stehen."]] },
  { id: "mila", name: "Test · Mila", hue: 120, sharing: defaultSharing, description: "Kleine, gezielte Merkliste und mehrere gemeinsame Favoriten", saved: [1,4,8,15,24,33,45,55], rated: [1,4,8,15,24,33,45,55,59,62], ratings: [3,3,3,2,3,1,3,2,3,2], notes: [[8,"Testnotiz: Gemeinsamer Favorit – rechtzeitig losgehen."],[45,"Testnotiz: Dieses Konzert wäre eine schöne Überraschung."]] },
  { id: "demo", name: "Demo · Alex", hue: 30, sharing: defaultSharing, description: "Hauptkonto: Festivalbesuch mit acht Freunden", saved: [0,1,2,4,6,8,9,10,12,14,16,18,21,24,27,30], rated: [0,1,2,4,5,6,8,9,10,12,14,16,18,21,24,27,30,33,36,39], ratings: [3,2,1,3,2,3,1,2,3,1,2,3,1,3,2,3,1,2,3,2], notes: [[4,"Meine Demo-Notiz: Hier wollen wir uns als Gruppe treffen."],[8,"Meine Demo-Notiz: Nicht verpassen, mehrere Freunde gehen auch hin."],[21,"Meine Demo-Notiz: Wenn es zu voll wird, eine Alternative suchen."],[30,"Meine Demo-Notiz: Noch nicht sicher, ob ich es zeitlich schaffe."]] },
];

const demoSharing = () => defaultSharing;
const connections = [
  { creator: "anna", recipient: "ben" }, { creator: "ben", recipient: "clara" }, { creator: "clara", recipient: "anna" },
  ...["david", "emilia", "fatima", "jonas", "mila"].map(id => ({ creator: id, recipient: "demo", recipientSharing: demoSharing(id) })),
  ...["anna", "ben", "clara"].map(id => ({ creator: "demo", recipient: id, sharing: demoSharing(id) })),
];

async function fixtures() {
  const catalog = JSON.parse(await readFile(new URL("../../../shared/src/commonMain/resources/FestivalBackup/2026_rudolstadt_data.json", import.meta.url), "utf8"));
  const artists = new Map(catalog.artists.filter(a => a.category === "concert" && !a.hide_artist).map(a => [a.id, a]));
  const seen = new Set();
  const events = catalog.events.filter(event => artists.has(event.artist)).sort((a,b) => a.start.date.localeCompare(b.start.date) || a.id - b.id)
    .filter(event => { if (seen.has(event.artist)) return false; seen.add(event.artist); return true; });
  assert.ok(events.length >= 64);
  const first = Array.from({ length: 18 }, (_, index) => events[Math.floor(index * (events.length - 1) / 17)]);
  const candidates = [...first, ...Array.from({ length: 64 }, (_, index) => events[Math.floor(index * (events.length - 1) / 63)]), ...events];
  const used = new Set();
  const pool = candidates.filter(event => { if (used.has(event.artist)) return false; used.add(event.artist); return true; }).slice(0,64);
  for (const value of definitions) {
    assert.equal(value.rated.length, value.ratings.length, `Rating count mismatch: ${value.id}`);
    assert.ok(value.saved.length + value.rated.length + value.notes.length + 1 <= 50);
  }
  return definitions.map(value => ({
    id: value.id, name: value.name, hue: value.hue, sharing: value.sharing, description: value.description,
    savedEventIDs: value.saved.map(index => pool[index].id),
    artistPreferences: value.rated.map((index, i) => ({ artistID: pool[index].artist, rating: value.ratings[i], iconName: value.ratings[i] === -1 ? "heart.fill" : null })),
    artistNotes: value.notes.map(([index, noteText]) => ({ artistID: pool[index].artist, noteText })),
  }));
}

await mkdir(folder, { recursive: true, mode: 0o700 });
await chmod(folder, 0o700);
const lock = await open(lockFile, "wx", 0o600);
let state;
const devices = [];
async function persist() {
  const temporary = new URL("test-users.json.tmp", folder);
  await writeFile(temporary, JSON.stringify(state, null, 2) + "\n", { mode: 0o600 });
  await chmod(temporary, 0o600);
  await rename(temporary, manifestFile);
}
function report() {
  const date = value => value ? new Intl.DateTimeFormat("de-DE", { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Tokyo" }).format(new Date(value)) + " (Tokio)" : "–";
  const lines = ["Firebase-Testnutzer – ausschließlich festival-friends-dev", "", "Enthält Zugangsschlüssel. Nicht ins Repository übernehmen oder öffentlich teilen.",
    "Einladungslink in der App unter Freunde einfügen. So bleibt dein eigenes Konto angemeldet.",
    "Zum direkten Anmelden an einem Testkonto dessen Schlüssel unter Konto → Mit Schlüssel anmelden verwenden.",
    "Demo · Alex ist bereits mit allen acht Testfreunden verbunden. Anna, Ben und Clara sind zusätzlich untereinander befreundet.",
    "Für die Festivalansicht mit mehreren Freunden zuerst das Demokonto öffnen; Details stehen in festival-demo.txt.",
    "Die Daten gehören zu Rudolstadt 2026.",
    "Einladungen sind einmalig und sieben Tage gültig. Erneuern: node firebase/functions/scripts/seed-test-users.mjs --refresh-invites", ""];
  for (const user of state.users) {
    lines.push(user.name, `UID: ${user.uid}`, `Zugangsschlüssel: ${user.key}`, `Einladungslink: ${user.inviteURL ?? "noch nicht erstellt"}`,
      `Erstellt: ${date(user.inviteCreatedAt)}; gültig bis: ${date(user.inviteExpiresAt)}`,
      `Gespeichert: ${user.profile.savedEventIDs.length} Konzertmerker, ${user.profile.artistPreferences.length} Bewertungen, ${user.profile.artistNotes.length} Notizen.`,
      `Standardfreigabe neuer Einladungen: ${Object.entries(user.profile.sharing).filter(([, enabled]) => enabled).map(([key]) => ({savedEvents:"Konzertmerker",ratings:"Bewertungen/Symbole",notes:"aktuelle Notizen"})[key]).join(", ")}.`, "");
  }
  return lines.join("\n");
}

function demoReport() {
  const user = state.users.find(value => value.id === "demo");
  const lines = ["FESTIVAL-DEMO: Alex mit acht Freunden", "Projekt: festival-friends-dev", "",
    `Konto: ${user.name}`, `Zugangsschlüssel: ${user.key}`, "",
    "In der App unter Konto das bisherige Konto abmelden und mit diesem Schlüssel anmelden.",
    "Die Kontodaten des bisherigen Kontos bleiben lokal erhalten; es wird nichts mit dem Demokonto vermischt.",
    "Die acht Freunde sind bereits verbunden. Es müssen keine Einladungen angenommen werden.", "",
    `Eigenes Profil: ${user.profile.savedEventIDs.length} Konzertmerker, ${user.profile.artistPreferences.length} Bewertungen und ${user.profile.artistNotes.length} Notizen.`,
    "Alle Konzerte und Künstler stammen aus dem gebündelten Rudolstadt-Programm 2026.",
    "Mehrere Merker überschneiden sich mit den Freunden; andere Freunde liefern zusätzliche Konzert- und Bewertungstipps.", "",
    "FREUNDESKREIS", ""];
  for (const friend of state.users.filter(value => value.id !== "demo")) {
    const profile = friend.profile;
    const shared = Object.entries(profile.sharing).filter(([,yes]) => yes).map(([key]) => ({savedEvents:"Merker",ratings:"Bewertungen",notes:"aktuelle Notizen"})[key]).join(", ");
    const common = profile.savedEventIDs.filter(id => user.profile.savedEventIDs.includes(id)).length;
    lines.push(`${friend.name}: ${profile.description ?? "Bekanntes Testprofil mit gemeinsamen Konzertmerkern"}`,
      `Sichtbar für Alex: ${shared}.` + (profile.sharing.savedEvents ? ` Gemeinsame Konzertmerker: ${common}.` : ""), "");
  }
  lines.push("Zum Ausprobieren: Freunde, gemeinsame Merker und Freundesempfehlungen öffnen und die eigene Merkliste ansehen.",
    "Alle Freunde teilen Markierungen und Bewertungen. Alle Notizen bleiben privat.",
    "Alle Zugangsdaten und optionalen Einladungslinks stehen in test-users.txt. Nicht veröffentlichen.");
  return lines.join("\n") + "\n";
}
async function createInvite(device, permissions) {
  try { return await device.call("createFriendInvite", { sharing: permissions }); }
  catch (error) {
    if (error.code !== "functions/resource-exhausted") throw error;
    await new Promise(resolve => setTimeout(resolve, 11_000));
    return device.call("createFriendInvite", { sharing: permissions });
  }
}
try {
  try { state = JSON.parse(await readFile(manifestFile, "utf8")); }
  catch (error) { if (error.code !== "ENOENT") throw error; }
  if (!state) {
    state = { schema: 1, projectId, edition, createdAt: new Date().toISOString(), complete: false,
      users: (await fixtures()).map(profile => ({ id: profile.id, name: profile.name, key: newKey(), uid: null, seeded: false, profile })), connections: {} };
    // Save each credential before the first remote operation so interrupted runs resume safely.
    await persist();
  }
  assert.equal(state.schema, 1); assert.equal(state.projectId, projectId); assert.equal(state.edition, edition);
  assert.ok(state.users.every(user => definitions.some(value => value.id === user.id)), "Unknown fixture account");
  const fresh = (await fixtures()).filter(profile => !state.users.some(user => user.id === profile.id));
  if (fresh.length) {
    state.users.push(...fresh.map(profile => ({ id: profile.id, name: profile.name, key: newKey(), uid: null, seeded: false, profile })));
    state.complete = false;
    await persist();
  }
  assert.deepEqual(state.users.map(user => user.id), definitions.map(value => value.id));
  if (!state.complete || refresh) {
    for (const user of state.users) {
      assert.ok(user.name.startsWith("Test · ") || (user.id === "demo" && user.name === "Demo · Alex"));
      const app = initializeApp(sdk, `seed-test-${user.id}`), auth = getAuth(app), db = getFirestore(app);
      const call = async (name, data = {}) => (await httpsCallable(getFunctions(app, "europe-west3"), name)({ protocol: 2, owner: auth.currentUser?.uid, ...data })).data;
      devices.push({ app, auth, db, call, user });
      const login = await call(user.uid ? "signInWithAccountKey" : "createKeyAccount", { key: user.key });
      if (user.uid) assert.equal(login.uid, user.uid, "Unexpected account identity");
      else { user.uid = login.uid; await persist(); }
      await signInWithCustomToken(auth, login.token);
      assert.equal(auth.currentUser.uid, user.uid);
      if (!user.seeded) {
        const profile = user.profile, modifiedAt = Date.parse(state.createdAt) / 1000;
        const record = (key, value) => ({ key, version: { modifiedAt, changeID: `dev-test-seed:${user.id}:${key}` }, ...value });
        const records = [record("profile", { badgeName: user.name, hue: profile.hue }),
          ...profile.savedEventIDs.map(id => record(`event:${id}`, { value: { kind: "event", id, isSaved: true } })),
          ...profile.artistPreferences.map(value => record(`rating:${value.artistID}`, { value: { kind: "rating", id: value.artistID, rating: value.rating, iconName: value.iconName } })),
          ...profile.artistNotes.map(value => record(`note:${value.artistID}`, { value: { kind: "note", id: value.artistID, noteText: value.noteText } }))];
        assert.ok(records.length <= 50);
        await call("syncOwnProfile", { edition, records });
        await call("setFriendIdentity", { identity: { name: user.name, hue: profile.hue } });
        await call("publishFriendProfile", { edition, profile });
        const stored = await getDocs(collection(db, `users/${user.uid}/profileEditions/${edition}/records`));
        assert.equal(stored.size, records.length);
        for (const value of profile.artistNotes) assert.equal(stored.docs.find(row => row.id === `note:${value.artistID}`).data().value.noteText, value.noteText);
        assert.deepEqual((await getDocFromServer(doc(db, `friendProfileEditions/${edition}/profiles/${user.uid}/categories/savedEvents`))).data().savedEventIDs, [...profile.savedEventIDs].sort((a,b) => a-b));
        user.seeded = true; await persist();
      }
    }
    if (!state.complete) {
      for (const connection of connections) {
        const creator = devices.find(device => device.user.id === connection.creator), recipient = devices.find(device => device.user.id === connection.recipient);
        const id = `${creator.user.id}:${recipient.user.id}`;
        if (!state.connections[id]) {
          const link = await createInvite(creator, connection.sharing ?? creator.user.profile.sharing);
          await recipient.call("acceptFriendInvite", { token: link.token, sharing: connection.recipientSharing ?? recipient.user.profile.sharing });
          state.connections[id] = true; await persist();
        }
      }
      for (const device of devices) {
        const expected = connections.filter(value => value.creator === device.user.id || value.recipient === device.user.id)
          .map(value => state.users.find(user => user.id === (value.creator === device.user.id ? value.recipient : value.creator)).uid);
        const rows = await getDocs(collection(device.db, `friendships/${device.user.uid}/friends`));
        for (const uid of expected) assert.ok(rows.docs.some(row => row.id === uid), "Fixture friendship missing");
      }
    }
    for (const device of devices) {
      if (!refresh && device.user.inviteURL) continue;
      const invite = await createInvite(device, device.user.profile.sharing);
      device.user.inviteURL = `https://festival.leongeorgi.de/rudolstadt/friends?v=2&token=${invite.token}`;
      device.user.inviteCreatedAt = new Date().toISOString();
      device.user.inviteExpiresAt = new Date(Date.now() + 7 * 86400_000).toISOString();
      await persist();
    }
    state.complete = true; await persist();
  }
  await writeFile(reportFile, report(), { mode: 0o600 }); await chmod(reportFile, 0o600);
  await writeFile(demoFile, demoReport(), { mode: 0o600 }); await chmod(demoFile, 0o600);
  process.stdout.write(`${state.users.length} Testkonten bereit; Demo · Alex hat acht vorbereitete Freunde.\nDemozugang: ${fileURLToPath(demoFile)}\nAlle Zugangsdaten: ${fileURLToPath(reportFile)}\n`);
} catch (error) {
  process.stderr.write(`Testnutzer-Einrichtung fehlgeschlagen (${error.code ?? error.name}). Gespeicherten Zwischenstand beim erneuten Aufruf fortsetzen.\n`);
  process.exitCode = 1;
} finally {
  await Promise.allSettled(devices.map(async device => { await signOut(device.auth); await terminate(device.db); await deleteApp(device.app); }));
  await lock.close(); await unlink(lockFile);
}
