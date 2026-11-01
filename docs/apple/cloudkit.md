# CloudKit profile change tracking

Profile schema version 3 adds three fields to `SavedEventPreference`,
`ArtistPreference`, and `ArtistNote`: `userModifiedAt` (Date/Time), `changeID`
(String), and `isDeleted` (Int64 boolean). Deploy these additive fields to the
production CloudKit schema before releasing this version. No schema deployment
is performed by the unit tests.

The user-edit timestamp stays fixed during upload retries. Removed values remain
as versioned deletion records so offline devices cannot restore an older value.
Notes retain their existing private record zone. Old records and local caches
remain readable without receiving an artificial current edit timestamp.

Older app binaries do not understand deletion markers; update all participating
devices, including friends' shared-profile readers, for consistent removals.
Physical deletions from older clients have no user-edit timestamp: they remove
legacy values, but cannot erase a newer, explicitly versioned local change.
