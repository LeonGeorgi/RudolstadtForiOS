import { test } from "node:test";
import assert from "node:assert/strict";
import { normalizeAccountKey, accountKeyHash, keyRateLimit, standaloneKeyOwner, standaloneKeyUser } from "../src/account-keys.js";

const key = "FF1-" + Array(8).fill("ZZZZ").join("-");
test("account keys normalize separators and case, reject malformed credentials and only expose a digest", () => {
  assert.equal(normalizeAccountKey(key.toLowerCase().replaceAll("-", " \n")), key);
  assert.match(accountKeyHash(key), /^[a-f0-9]{64}$/);
  assert.equal(accountKeyHash(key.toLowerCase()), accountKeyHash(key));
  for (const value of [null, "short", key + "Z", key.replace("FF1", "FF2"), key.replaceAll("Z", "O"), "https://example.org/?key=" + key])
    assert.throws(() => normalizeAccountKey(value), e => e.code === "unauthenticated");
});

test("rate limiting bounds attempts, resets after one hour, and never stores the client IP", async () => {
  const values = new Map();
  const db = { collection: () => ({ doc: id => id }), runTransaction: async run => run({
    get: async id => ({ data: () => values.get(id) }), set: (id, value) => values.set(id, value),
  }) };
  await keyRateLimit(db, "test", "192.0.2.1", 2, 1000);
  await keyRateLimit(db, "test", "192.0.2.1", 2, 2000);
  await assert.rejects(keyRateLimit(db, "test", "192.0.2.1", 2, 3000), e => e.code === "resource-exhausted");
  await keyRateLimit(db, "test", "192.0.2.1", 2, 3601000);
  assert.equal(values.size, 1);
  assert.equal([...values.values()][0].count, 1);
  assert.equal(JSON.stringify([...values]).includes("192.0.2.1"), false);
});

test("standalone ownership rejects supplemental keys and any external provider", () => {
  assert.equal(standaloneKeyOwner("apple-user", { kind: "standalone" }), false);
  assert.equal(standaloneKeyOwner("key_XXXXXXXXXXXXXXXXXXXXXXXX", { version: 1 }), true);
  assert.equal(standaloneKeyOwner("key_XXXXXXXXXXXXXXXXXXXXXXXX", null), false);
  assert.equal(standaloneKeyUser({ providerData: [] }), true);
  for (const providerId of ["apple.com", "google.com", "password", "github.com"]) assert.equal(standaloneKeyUser({ providerData: [{ providerId }] }), false);
  assert.equal(standaloneKeyUser({ providerData: [], email: "owner@example.org" }), false);
  assert.equal(standaloneKeyUser({ providerData: [], disabled: true }), false);
});
