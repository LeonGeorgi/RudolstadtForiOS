import { test } from "node:test";
import assert from "node:assert/strict";
import { profilePayload } from "../src/protocol.js";
import { permissions, validateGlobalInvite } from "../src/global-friends.js";

test("only intended profile fields are published", () => {
  assert.deepEqual(profilePayload({
    name: " Alex ", hue: 30, savedEventIDs: [2, 1, 2],
    artistPreferences: [{ artistID: 3, rating: 2 }], artistNotes: ["secret"], email: "private@example.org",
  }), { name: "Alex", hue: 30, savedEventIDs: [1, 2],
    artistPreferences: [{ artistID: 3, rating: 2, iconName: null }] });
});
test("rejects malformed and oversized profile data", () => {
  const base = { name: "Alex", hue: 30, savedEventIDs: [], artistPreferences: [] };
  for (const invalid of [{ name: "" }, { savedEventIDs: [-1] }, { savedEventIDs: Array(5001).fill(1) },
    { artistPreferences: [{ artistID: 1, rating: 100 }] }]) {
    assert.throws(() => profilePayload({ ...base, ...invalid }));
  }
});
test("global invitations reject legacy, self, expired, consumed and revoked tokens", () => {
  const invite = { version: 2, owner: "alice", expiresAt: { toMillis: () => 100 } };
  validateGlobalInvite(invite, "bob", 99);
  for (const [value, uid, now] of [[invite, "alice", 99], [invite, "bob", 100], [{ ...invite, usedBy: "carol" }, "bob", 99], [{ ...invite, revoked: true }, "bob", 99], [{ ...invite, version: 1 }, "bob", 99], [undefined, "bob", 99]])
    assert.throws(() => validateGlobalInvite(value, uid, now));
});
test("per-friend permissions allow only explicit boolean concert, rating and note choices", () => {
  assert.deepEqual(permissions({ savedEvents: false, ratings: true, notes: true }), { savedEvents: false, ratings: true, notes: true });
  for (const value of [null, {}, { savedEvents: "yes", ratings: true }, { savedEvents: true }, { savedEvents: true, ratings: true, notes: "yes" }]) assert.throws(() => permissions(value));
});

test("profile colors store only a finite OKHSL hue in degrees", () => {
  const base = { name: "Alex", savedEventIDs: [], artistPreferences: [] };
  assert.deepEqual(profilePayload({ ...base, hue: 359.5, color: "#FFFFFF", saturation: 1, lightness: 1 }),
    { ...base, hue: 359.5 });
  for (const hue of [undefined, null, "30", -1, 360, Infinity, NaN]) {
    assert.throws(() => profilePayload({ ...base, hue }));
  }
});
