import { test } from "node:test";
import assert from "node:assert/strict";
import { ownerRecord, compareOwnerRecords } from "../src/owner-profile.js";

const note = (text, modifiedAt = 1, changeID = "a") => ({ key: "note:7", version: { modifiedAt, changeID },
  value: { kind: "note", id: 7, noteText: text } });

test("private records retain complete note text and only validated fields", () => {
  const text = "Private 😀\n".repeat(10000);
  const value = ownerRecord({ ...note(text), friends: ["other"], owner: "someone", email: "secret@example.org" });
  assert.equal(value.value.noteText, text);
  assert.equal(value.owner, undefined);
  assert.equal(value.friends, undefined);
  assert.equal(value.email, undefined);
  assert.equal(ownerRecord({ key: "profile", version: { modifiedAt: 0, changeID: "legacy:a" }, badgeName: null, hue: 30 }).badgeName, null);
});

test("invalid paths, values and versions cannot enter the private sync", () => {
  for (const record of [
    { ...note("x"), key: "note:../other" }, { ...note("x"), key: "note:07" },
    { ...note("x"), value: { kind: "rating", id: 7, rating: 4 } },
    { ...note("x"), version: { modifiedAt: Infinity, changeID: "a" } },
    { ...note("x"), version: { modifiedAt: 1, changeID: "" } },
    { ...note("x"), value: { kind: "note", id: 8, noteText: "x" } },
    { ...note("x"), value: { kind: "note", id: 7, noteText: 10 } },
  ]) assert.throws(() => ownerRecord(record));
});

test("versions and deterministic ties preserve deletion intent across retries", () => {
  assert.ok(compareOwnerRecords(ownerRecord(note("", 3)), ownerRecord(note("old", 2))) > 0);
  assert.ok(compareOwnerRecords(ownerRecord(note("new", 3, "z")), ownerRecord(note("old", 3, "a"))) > 0);
  assert.equal(compareOwnerRecords(ownerRecord(note("same")), ownerRecord(note("same"))), 0);
  assert.ok(compareOwnerRecords(ownerRecord(note("z")), ownerRecord(note("a"))) > 0);
});

test("private badge records store only hue and compare it numerically", () => {
  const badge = hue => ownerRecord({ key: "profile", version: { modifiedAt: 1, changeID: "same" },
    badgeName: "Alex", hue, badgeColor: "#FFFFFF", saturation: 1, lightness: 1 });
  assert.deepEqual(badge(210.5), { key: "profile", version: { modifiedAt: 1, changeID: "same" },
    value: null, badgeName: "Alex", hue: 210.5 });
  for (const hue of [null, "30", -1, 360, NaN, Infinity]) assert.throws(() => badge(hue));
  assert.ok(compareOwnerRecords(badge(100), badge(30)) > 0);
  assert.equal(compareOwnerRecords(badge(30), badge(30.0)), 0);
});
