# Festivaldaten und Integrationen

Alle Code- und Ressourcenpfade sowie Shell-Befehle in diesem Dokument beziehen sich
auf den Projektstamm. Programme, Archive und Zusatzdaten liegen gemeinsam in
`shared/src/commonMain/resources`. Native Apple-Adapter laden diese Dateien und
verbinden den Kotlin-Kern mit SwiftUI, Persistenz und Systemdiensten. Die folgenden
Details beschreiben diese Integration; die Aufteilung zwischen Kotlin und Swift
steht im [Projektüberblick](../README.md).

## Festival integrations

`iosApp/Shared/Core/FestivalInterfaces.swift` defines the neutral `FestivalAdapter`
contract. A registered adapter provides metadata, a complete `FestivalData` program,
its cache/bundle/refresh lifecycle, and optional independent services.
`iosApp/Shared/Data/FestivalRegistry.swift` is the composition and registration point.
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

## Concert details and editorial content

Concert details are an explicit opt-in on the shared `FestivalProgram`:

- `eventDetails = null` means the festival does not support concert detail pages.
- `EventDetailsFeature(contents = emptyList())` enables them with the concert's basic information.
- `EventDetailContent(eventID, content)` supplies additional content for an existing event.

The feature owns all concert-specific `ProgramEditorialContent`. Neither
`ProgramOccurrence` nor `EventMetadata` (including the Swift `Event` initializer)
accepts editorial content. There is no independent Boolean switch. Supplying the
feature is the only way to enable the capability and attach concert information.

```kotlin
val program = FestivalProgram(
    artists = artists,
    areas = areas,
    places = places,
    events = events,
    omittedRecordCount = 0,
    year = 2026,
    eventDetails = EventDetailsFeature(
        contents = listOf(
            EventDetailContent(
                eventID = workshop.eventID,
                content = ProgramEditorialContent(
                    article = ProgramContent(mapOf("de" to "Gemeinsam musizieren")),
                    fields = listOf(
                        ProgramInformationField(
                            "equipment",
                            mapOf("de" to "Mitbringen"),
                            mapOf("de" to "Eigenes Instrument"),
                        )
                    ),
                    links = listOf(
                        ProgramLink("registration", mapOf("en" to "Registration"),
                            "https://example.com/workshop")
                    ),
                ),
            )
        )
    ),
)
```

Preparation and normalized-cache import/export reject duplicate detail entries
and references to unknown events. Current cache format 2 stores the feature at
program level. Format 1 caches are migrated explicitly: existing inline concert
content becomes a feature block; caches without such content remain unsupported.
Current-format caches cannot use the old inline field to bypass the feature.

`ProgramCatalogs` exposes the same optional `EventDetailsFeature` to Android and
Apple. Swift's `FestivalFeatures.eventDetails` wraps it in `FeatureAvailability`,
retaining the distinction between unsupported, available, and temporarily
unavailable. Provider enrichment preserves the feature as part of the immutable
shared program; it does not attach separate content to events.

When the feature is supported, concert entries in artist, stage, schedule, and
program-discovery lists open the concert detail page, even when a particular
concert has no additional editorial content. The page provides the date, time,
existing save action, optional content, and explicit links to artist and stage.
Unsupported festivals retain their existing destinations. The artist screen has
no separate inline concert-details disclosure. A temporarily unavailable Apple
feature keeps the concert destination and displays an explicit availability hint.

Tags remain ordinary program metadata and do not enable concert details. Tag
membership, discoverability and `Programm entdecken` read the program's tags
independently of this feature. A `ProgramTag` can still carry editorial category
content and `introductionTexts`; those describe a topic rather than an individual
concert. Category introductions retain their existing festival-policy fallback.

`ProgramEditorialContent` consists of a localized plain-text/HTML `article`,
labeled `fields` with stable IDs, and localized `links` with their browser-opening
mode. The Swift aliases remain `FestivalEditorialContent` and
`FestivalInformationField`. Browser modes, language fallback and read-only
festival permissions continue to use the existing app behavior. External source
formats and personal profile schemas are unchanged; a festival source must supply
the actual optional concert content.

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
python3 scripts/data/import_festival_archive.py /path/to/exports shared/src/commonMain/resources/FestivalBackup/2024_archive.json --year 2024
python3 scripts/data/import_festival_archive.py /path/to/apk/assets shared/src/commonMain/resources/FestivalBackup/2025_archive.json --year 2025 --source-version 12.3.0 --source-url https://apkpure.net/rudolstadt-festival/de.dbware.tff/download/12.3.0
```

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
python3 scripts/data/import_ludwigsburg.py /path/to/strassenmusik-ludwigsburg/2026 \
  shared/src/commonMain/resources/FestivalBackup/ludwigsburg_2026.json \
  --map-output-directory shared/src/commonMain/resources/FestivalBackup
```

The importer also verifies the PDF checksum against
`scripts/data/ludwigsburg_2026_site_plan.json` before including its curated locations.
If the official plan changes, review that file first; the importer rejects an
unreviewed plan. Generic PDF display and place models remain usable by other adapters.
