export class FriendError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

export function requireValue(condition, code = "invalid-argument", message = code) {
  if (!condition) throw new FriendError(code, message);
}

export function profilePayload(value) {
  requireValue(value && typeof value === "object");
  const { name, hue, savedEventIDs, artistPreferences } = value;
  requireValue(typeof name === "string" && name.trim().length > 0 && name.length <= 40);
  requireProfileHue(hue);
  const validID = id => Number.isSafeInteger(id) && id >= 0;
  requireValue(Array.isArray(savedEventIDs) && savedEventIDs.length <= 5000 && savedEventIDs.every(validID));
  requireValue(Array.isArray(artistPreferences) && artistPreferences.length <= 5000);
  const preferences = new Map();
  for (const entry of artistPreferences) {
    requireValue(entry && validID(entry.artistID) && Number.isInteger(entry.rating) && entry.rating >= -1 && entry.rating <= 3);
    requireValue(entry.iconName == null || (typeof entry.iconName === "string" && entry.iconName.length <= 100));
    preferences.set(entry.artistID, {
      artistID: entry.artistID, rating: entry.rating, iconName: entry.iconName ?? null,
    });
  }
  // Explicit allowlist: never persist notes, email addresses or supplied permissions.
  return {
    name: name.trim(), hue,
    savedEventIDs: [...new Set(savedEventIDs)].sort((a, b) => a - b),
    artistPreferences: [...preferences.values()].sort((a, b) => a.artistID - b.artistID),
  };
}

export function requireProfileHue(hue) {
  requireValue(typeof hue === "number" && Number.isFinite(hue) && hue >= 0 && hue < 360);
}
