# Rudolstadt for iOS

An independently developed, unofficial Rudolstadt Festival app, built with Swift
and SwiftUI and published on the App Store since June 2022. It helps visitors
discover artists and plan their festival across overlapping concerts and venues.
The app supports iPhone and iPad, in German and English.

[Download on the App Store](https://apps.apple.com/us/app/rudolstadt-festival-unoff/id1629927812)
| [Project background and my contribution](https://leongeorgi.de/projects/rudolstadt-festival-app)

## Product decisions and maintenance

- **Artist interest and attendance are separate.** Rating an artist expresses a
  preference; saving a concert makes it part of the visitor's plan.
- **Recommendations respect the visit.** Schedule suggestions consider artist
  preferences, overlapping concerts and walking time between venues.
- **Published and maintained.** The app includes a custom timetable, maps and
  CloudKit sharing. The June 2026 release added friend features and an artist
  world map. The App Store history records shipped versions; repository work
  may include changes that have not yet been released.

## Code and tests

The app combines SwiftUI screens with festival-data conversion, recommendation
logic and CloudKit-backed sharing. Examples of the automated checks are the
[recommendation service tests](Unit%20Tests/Domain/RecommendationServiceTests.swift)
and [data conversion tests](Unit%20Tests/Parsing/DataConverterTests.swift).
The [fast-test workflow](.github/workflows/ios-fast-tests.yml) and
[screenshot workflow](.github/workflows/ios-screenshot-tests.yml) document the
corresponding automation. For run results, see the individual workflow runs.


## Screenshots

### iPhone

<p align="center">
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/iphone/de/01-schedule.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/iphone/de/01-schedule.png" width="150" alt="Schedule on iPhone"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/iphone/de/02-artists.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/iphone/de/02-artists.png" width="150" alt="Artists on iPhone"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/iphone/de/03-locations.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/iphone/de/03-locations.png" width="150" alt="Locations on iPhone"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/iphone/de/04-artist-detail.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/iphone/de/04-artist-detail.png" width="150" alt="Artist details on iPhone"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/iphone/de/05-friends.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/iphone/de/05-friends.png" width="150" alt="Friends' recommendations on iPhone"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/iphone/de/06-artist-world-map.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/iphone/de/06-artist-world-map.png" width="150" alt="Artist world map on iPhone"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/iphone/de/07-schedule-dark.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/iphone/de/07-schedule-dark.png" width="150" alt="Schedule in Dark Mode on iPhone"></a>
</p>

### iPad

<p align="center">
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/ipad/de/01-schedule.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/ipad/de/01-schedule.png" width="220" alt="Schedule on iPad"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/ipad/de/02-artists.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/ipad/de/02-artists.png" width="220" alt="Artists on iPad"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/ipad/de/03-locations.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/ipad/de/03-locations.png" width="220" alt="Locations on iPad"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/ipad/de/04-artist-detail.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/ipad/de/04-artist-detail.png" width="220" alt="Artist details on iPad"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/ipad/de/05-friends.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/ipad/de/05-friends.png" width="220" alt="Friends' recommendations on iPad"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/ipad/de/06-artist-world-map.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/ipad/de/06-artist-world-map.png" width="220" alt="Artist world map on iPad"></a>
  <a href="https://leongeorgi.github.io/RudolstadtForiOS/screenshots/ipad/de/07-schedule-dark.png"><img src="https://leongeorgi.github.io/RudolstadtForiOS/thumbnails/ipad/de/07-schedule-dark.png" width="220" alt="Schedule in Dark Mode on iPad"></a>
</p>

[View all 28 screenshots in full resolution and download them together](https://leongeorgi.github.io/RudolstadtForiOS/)

The latest screenshots are generated by the manually triggered GitHub Actions workflow in `.github/workflows/ios-screenshot-tests.yml`. Successful runs publish the optimized previews shown above, retain every full-resolution German and English iPhone and iPad screenshot, and provide a ZIP containing all originals.

## Special Features
- Dark mode
- Search in lists
- Stage numbers
- Nearby stages
- In-app map
- Save events in-app
- Warning message for events that overlap with a saved event
- Rate artists
- Calculate the best possible schedule according to artist rating (shown as recommendations)

## Festival integrations

`Shared/Core/FestivalInterfaces.swift` defines the neutral `FestivalAdapter`
contract. A registered adapter provides metadata, a complete `FestivalData` program,
its cache/bundle/refresh lifecycle, and optional independent services.
`Shared/Data/FestivalRegistry.swift` is the composition and registration point.
Add an adapter to its catalog to make an edition selectable throughout the app;
`AppServices(festivalAdapter:)` also accepts an adapter for explicit injection.

The program contains artists, places, events and full calendar-based festival
days. Event durations belong to the program, including whether they were
estimated. They remain available to the timeline when automatic planning is off.
`LocalizedText` uses language tags supplied by the source, with regional and
configured default-language fallback rather than a supported-language enum.

Features are independent `FeatureAvailability` values: information, artist/place/
event details, admission, artist summaries, groupings, similarities, areas, maps,
original site plans, distances and automatic planning. An integration implements
only the small provider protocols it supports. `unsupported` omits a function;
`unavailable` represents a supported function that currently failed. Providers
serve immutable loaded values; views do not perform per-row network requests.
A map provider can offer geographic and illustrated SVG/image/PDF maps together,
with source-defined categories and normalized positions. Distances and planning
are separate capabilities; approximate map pins do not enable planning.

Sources, calculations and screens use the same `FestivalData`, `Artist`, `Stage`
and `Event` values. There is no intermediate snapshot model or presentation
round trip. Artist details hold localized content and links once; event durations
retain whether they were published or estimated. `DataStore` validates the program
identity and references, then publishes the whole program together with its
provenance. Derived source/backup properties read that same published value. Cache metadata
remains independent so deleting the on-disk cache does not change the provenance
of the still-visible program.
Invalid optional map data cannot replace the whole program with an error. Remote, cached, stale, bundled, preview and screenshot provenance stay
explicit. News loads independently and routes include both festival and edition.
Local saved-event, rating and note permissions can differ independently.

`FestivalSourceAdapter` adds edition-specific days, capabilities and provenance
to the source's program without translating entities into another representation.
`FestivalDataProviding` remains an internal loading/conversion boundary
for those integrations; it is no longer the interface consumed by app composition.
Rudolstadt keeps its existing API/cache/backup files and personal profile formats.
Other festivals use scoped local profiles; existing Ludwigsburg namespaces remain
readable. CloudKit sharing and Watch transport remain restricted to the existing
Rudolstadt integration and have not been generalized. The versioned Watch snapshot
remains a separate transport format; personal profile and CloudKit schemas are
unchanged.

Targeted `FestivalAdapterContractTests` cover optional features, both map kinds,
non-numeric place IDs, logical festival days across midnight, duration independence,
identity validation, arbitrary content languages, scoped profiles and news state.

## Festival archive

Settings offers the current 2026 program and read-only archives for 2019 and
2022–2025. The selection persists across launches and replaces the festival data
throughout the regular app screens. There is no complete 2020 or 2021 program;
the incomplete 2020 planning export is not offered as a festival archive.

Composition lazily retains one DataStore per edition. Archive profiles read
locally saved events, ratings, alternative icons and notes for that year only.
They prefer the year-specific profile cache, then a matching old global cache,
then the original per-year preferences. Reading an archive never migrates or
writes profile storage, and CloudKit sync and editing are disabled. No personal
data is recovered from CloudKit for an earlier year. Saved/liked filters remain
available; schedule filters and map preferences are scoped to each festival and edition. Watch transport stays attached to the current festival.
News, shared profiles and travel information are not offered in the archive.
Screenshot mode always selects the current festival.

`RudolstadtArchiveDataProvider` loads immutable `FestivalBackup/<year>_archive.json`
snapshots and validates their schema, year, IDs, references and dates before
publishing a program. Text and schedules work offline; artist images use the
original remote thumbnail and full-image URLs and depend on their availability.
No current-year curated artist metadata or walking distances are applied to old
years. The archive remains a captured program, not a claim to the final timetable.

| Year | Source | Artists | Events | Stages |
| --- | --- | ---: | ---: | ---: |
| 2019 | Official Android app 8.2.0, bundled production assets | 158 | 290 | 48 |
| 2022 | Official website text export | 142 | 259 | 46 |
| 2023 | Official website text export | 140 | 282 | 43 |
| 2024 | Official website text export (existing snapshot retained) | 151 | 304 | 45 |
| 2025 | Official Android app 12.3.0, bundled production assets | 154 | 294 | 35 |

The snapshots retain their source URLs and capture time. Newly imported snapshots
also identify APK versions and source-file SHA-256 hashes. To reproduce one from
five `.dat` exports or five JSON assets (`artists`, `areas`, `stages`, `events`,
`tags`):

```sh
python3 scripts/import_festival_archive.py /path/to/exports Shared/Resources/FestivalBackup/2024_archive.json --year 2024
python3 scripts/import_festival_archive.py /path/to/apk/assets Shared/Resources/FestivalBackup/2025_archive.json --year 2025 --source-version 12.3.0 --source-url https://apkpure.net/rudolstadt-festival/de.dbware.tff/download/12.3.0
```

## CloudKit profile change tracking

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

## Experimental Ludwigsburg integration

Settings → Festival offers **Straßenmusikfestival Ludwigsburg 2026** throughout
the regular app. `LudwigsburgFestivalDataProvider` reads an independent bundled
snapshot: 37 artists, 11 stages and 219 performances on 20–21 June 2026, including
published durations, German descriptions, country metadata and remote image URLs.
This is a saved program, with no live refresh. Images still require network access.
The award concert is omitted because the downloaded timetable has conflicting
times; the app displays its incomplete-import notice.

Ratings, notes and saved events use a separate local persistence namespace. They
never use Rudolstadt's profile cache, legacy migration or CloudKit zones. Sharing,
Rudolstadt news/travel information, artist deep links and Watch publishing are not
part of the integration. The official site plan is bundled as a zoomable PDF, with
11 stage positions and 38 additional places/offers in `FestivalSitePlan`. The places
list is searchable; stages and other places can open their highlighted position.
Entrances, food, toilets, parking, first aid, services and activities remain distinct
from performance stages. External parking references and legend-only offers have
no fabricated diagram position. A local landmark comparison with OpenStreetMap
additionally supplies approximate geographic coordinates for all 11 stages and
35 other places; Bärenwiese uses the operator's shared arrival point. The app
labels these estimates, preserves their source attribution, and offers both the
geographic map and the original plan. Face painting, photo booth and the ambiguous
combined Rathaus/Mathilde parking reference have no geographic pin. Approximate
stage positions do not qualify events for automatic route planning.

To disable the experiment, remove its adapter from `FestivalRegistry.catalog`.
Existing selections fall back to the catalog default; personal data is retained.
Full removal additionally deletes the provider, snapshot, site-plan PDF and their
Xcode membership, along with the registration-specific convenience identity. The general selection identity, persistence namespace, published event
durations and image-URL color-cache keys also serve other festival adapters.

Regenerate the snapshot from the previously downloaded official source directory:

```sh
python3 scripts/import_ludwigsburg.py /path/to/strassenmusik-ludwigsburg/2026 \
  Shared/Resources/FestivalBackup/ludwigsburg_2026.json
```

The importer also verifies the PDF checksum against
`scripts/ludwigsburg_2026_site_plan.json` before including its curated locations.
If the official plan changes, review that file first; the importer rejects an
unreviewed plan. Generic PDF display and place models remain usable by other adapters.
