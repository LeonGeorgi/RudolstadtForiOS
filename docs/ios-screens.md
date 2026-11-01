# iOS and Android screen checklist

- Inventory: 43 functional scopes
- Includes: screens, variants, states
- One row per functional item
- Equal scope; platform-native presentation
- ✅ Implemented; equivalent reachable flows included
- ◐ Partial; limits in presentation notes
- ☐ No matching implementation found
- Original iOS checks: retained
- Added iOS gaps: source-checked
- Android rows: 332 complete, 61 partial, 204 absent
- Scope presentation/source: first row
- Row notes: exceptions and differences
- iOS source: `iosApp`
- Android source: `androidApp`
- Source review: October 29, 2026
- Schedule update: 25 targeted iOS tests passed
- Full-screen runtime review: not performed

| Screen / scope | Type | Functional item | iOS | Android | Platform presentation |
| --- | --- | --- | :---: | :---: | --- |
| App | App navigation | Initial destination: Schedule | ✅ | ✅ | iOS: Schedule tab; Android: Programme start destination |
| App | App navigation | Primary navigation destinations | ✅ | ✅ | iOS: Locations, Schedule, Artists, Friends, More; Android: Programme, Artists, Map, News, More |
| App | App navigation | Preserve section navigation state | ✅ | ✅ | iOS: per-tab history; Android: Saved/restored section navigation; transient state may reset |
| App | App navigation | Reselect active destination | ✅ | ✅ | iOS: reset stack; Android: Single-top navigation; no scroll-to-top/reset handler |
| App | App navigation | Return to previous context | ✅ | ✅ | iOS: back navigation; Android: NavHost back stack + app-bar Back; predictive animation untested |
| App | App navigation | Close temporary view → source | ✅ | ✅ | iOS: modal dismissal; Android: Compose dialog/sheet dismissal |
| App | Festival differences | Current: Rudolstadt 2026 | ✅ | ✅ | — |
| App | Festival differences | Archives: 2025, 2024, 2023, 2022, 2019 | ✅ | ✅ | — |
| App | Festival differences | Experimental: Ludwigsburg 2026 | ✅ | ✅ | — |
| App | Festival differences | Archives: personal data read-only | ✅ | ✅ | — |
| App | Festival differences | Archives: visible archive notice | ✅ | ✅ | — |
| App | Festival differences | Experimental: local personal data | ✅ | ✅ | — |
| App | Festival differences | Experimental: friend sharing unavailable | ✅ | ✅ | Android: Sharing unavailable across all Android editions |
| App | Festival differences | Experimental: automatic planning unavailable | ✅ | ✅ | — |
| App | Festival differences | Optional features: availability-dependent | ✅ | ◐ | Android: Planning/news gated; summaries/Information not consistently gated |
| 1. Locations — festival map | Shows | Geographic map / illustrated plan | ✅ | ✅ | iOS: map tab; Android: MapLibre/OSM or bundled raster plan; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt) |
| 1. Locations — festival map | Shows | Place markers | ✅ | ✅ | — |
| 1. Locations — festival map | Shows | Category legend | ✅ | ◐ | Android: Category filter labels; no coloured map legend |
| 1. Locations — festival map | Shows | User location (permission required) | ✅ | ✅ | Android: Permission request; last-known position on demand |
| 1. Locations — festival map | Shows | Approximate-coordinate warning | ✅ | ◐ | Android: Selected-place details only |
| 1. Locations — festival map | Shows | Coordinate source link | ✅ | ☐ | Android: No coordinate-source link; OSM attribution only |
| 1. Locations — festival map | Actions | Pan and zoom | ✅ | ✅ | — |
| 1. Locations — festival map | Actions | Recenter map | ✅ | ◐ | Android: Site-plan reset; geographic map locates user only |
| 1. Locations — festival map | Actions | Toggle place categories | ✅ | ✅ | Android: Single category / All; not independent multi-toggle |
| 1. Locations — festival map | Actions | Switch available maps | ✅ | ☐ | Android: One map type per edition; no map picker |
| 1. Locations — festival map | Actions | Select place marker | ✅ | ✅ | — |
| 1. Locations — festival map | Actions | Use illustrated-map zoom buttons | ✅ | ☐ | Android: Pinch + reset only; no zoom-in/out buttons |
| 1. Locations — festival map | Navigation | Marker → place details | ✅ | ✅ | iOS: sheet; Android: Standard bottom sheet; side panel on wide windows |
| 1. Locations — festival map | Navigation | Open locations list | ✅ | ✅ | iOS: toolbar list button; Android: Toolbar list toggle; also map-panel list |
| 1. Locations — festival map | Navigation | Source link → website | ✅ | ☐ | Android: No coordinate-source link; OSM attribution only |
| 1. Locations — festival map | Actions | Filter places by area | ☐ | ✅ | iOS: area search/grouping only; Android: area filter; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt) |
| 1. Locations — festival map | Actions | Combine area and admission filters | ☐ | ✅ | iOS: admission legend, no area filter; Android: independent filters; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt) |
| 1. Locations — festival map | Actions | Clear map filters | ☐ | ✅ | iOS: category toggles only; Android: reset filters/search; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt) |
| 2. Locations — list | Shows | Place names and references | ✅ | ✅ | iOS: list sheet; Android: List toggle / map-panel list; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt) |
| 2. Locations — list | Shows | Area / category groups | ✅ | ◐ | Android: Area labels + filters; no grouped list headings |
| 2. Locations — list | Shows | Non-performance place notes | ✅ | ☐ | Android: PlaceRow shows area, not description |
| 2. Locations — list | Shows | Original plan link (if available) | ✅ | ☐ | Android: No original PDF viewer or link |
| 2. Locations — list | Actions | Search place names | ✅ | ✅ | — |
| 2. Locations — list | Actions | Search references | ✅ | ✅ | — |
| 2. Locations — list | Actions | Search descriptions | ✅ | ✅ | — |
| 2. Locations — list | Actions | Search areas | ✅ | ✅ | — |
| 2. Locations — list | Actions | Browse groups | ✅ | ✅ | Android: Through area/category filter choices |
| 2. Locations — list | Navigation | Place → place details | ✅ | ✅ | iOS: sheet navigation; Android: List route opens place page |
| 2. Locations — list | Navigation | Plan → document viewer | ✅ | ☐ | Android: No original PDF viewer or link |
| 2. Locations — list | Navigation | Close → festival map | ✅ | ✅ | Android: List/map toggle |
| 3. Place / stage detail | Shows | Place name and reference | ✅ | ✅ | iOS: page / map sheet; Android: Place page / standard bottom sheet / wide side panel; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt) |
| 3. Place / stage detail | Shows | Area and admission category | ✅ | ✅ | — |
| 3. Place / stage detail | Shows | Place description | ✅ | ✅ | — |
| 3. Place / stage detail | Shows | Related links | ✅ | ✅ | — |
| 3. Place / stage detail | Shows | Selected-day events | ✅ | ✅ | — |
| 3. Place / stage detail | Shows | Saved status | ✅ | ✅ | — |
| 3. Place / stage detail | Shows | Friend attendance badges | ✅ | ☐ | Android: No friend profiles |
| 3. Place / stage detail | Shows | Place map preview | ✅ | ✅ | iOS: standalone page only |
| 3. Place / stage detail | Shows | Nearby stages | ✅ | ✅ | iOS: standalone page only; Android: Visible on page and inside map panel |
| 3. Place / stage detail | Shows | Distances and walking times | ✅ | ✅ | — |
| 3. Place / stage detail | Shows | Unknown / approximate location warnings | ✅ | ◐ | Android: Approximate warning only; no unknown-location label |
| 3. Place / stage detail | Actions | Switch program day | ✅ | ✅ | — |
| 3. Place / stage detail | Actions | Save / remove events | ✅ | ✅ | — |
| 3. Place / stage detail | Actions | Open event preview | ✅ | ☐ | iOS: long press + context menu; Android: EventRow has navigation/bookmark only |
| 3. Place / stage detail | Actions | Expand location information | ✅ | ☐ | iOS: disclosure in map sheet; Android: Information always inline; no disclosure control |
| 3. Place / stage detail | Actions | Expand place details | ✅ | ✅ | iOS: sheet heights; Android: BottomSheetScaffold expansion on compact windows |
| 3. Place / stage detail | Navigation | Event → highlighted artist details | ✅ | ✅ | — |
| 3. Place / stage detail | Navigation | Nearby stage → stage details | ✅ | ✅ | — |
| 3. Place / stage detail | Navigation | Map preview → interactive map | ✅ | ✅ | — |
| 3. Place / stage detail | Navigation | Open external map app | ✅ | ✅ | iOS: Apple Maps; Android: geo: directions intent |
| 3. Place / stage detail | Navigation | Related links → destinations | ✅ | ✅ | — |
| 3. Place / stage detail | Navigation | Close details → festival map | ✅ | ✅ | iOS: sheet dismissal; Android: Close selection / Back; map remains available |
| 4. Interactive stage map | Shows | Stage name | ✅ | ✅ | iOS: map sheet; Android: stage-map route + selected-place panel; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt); Android: Selected-place panel; generic map toolbar title |
| 4. Interactive stage map | Shows | Interactive geographic map | ✅ | ✅ | — |
| 4. Interactive stage map | Shows | User location (when available) | ✅ | ✅ | — |
| 4. Interactive stage map | Actions | Pan and zoom | ✅ | ✅ | — |
| 4. Interactive stage map | Actions | Recenter on user location | ✅ | ✅ | — |
| 4. Interactive stage map | Navigation | Open external map app | ✅ | ✅ | iOS: Apple Maps; Android: Directions button inside selected-place panel |
| 4. Interactive stage map | Navigation | Close → stage details | ✅ | ✅ | — |
| 5. Original festival plan — document viewer | Shows | PDF site plan | ✅ | ☐ | Android: No PDF/document viewer; raster map only; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt) |
| 5. Original festival plan — document viewer | Shows | Official source link | ✅ | ☐ | — |
| 5. Original festival plan — document viewer | Shows | Document-unavailable message | ✅ | ☐ | — |
| 5. Original festival plan — document viewer | Actions | Scroll document | ✅ | ☐ | — |
| 5. Original festival plan — document viewer | Actions | Zoom document | ✅ | ☐ | — |
| 5. Original festival plan — document viewer | Navigation | Source → official website | ✅ | ☐ | — |
| 5. Original festival plan — document viewer | Navigation | Back → locations list | ✅ | ☐ | — |
| 6. Schedule — timeline | Shows | Selected-day events | ✅ | ✅ | Android: Timeline + zoom controls + action menus; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Timeline.kt) |
| 6. Schedule — timeline | Shows | Stage columns | ✅ | ✅ | — |
| 6. Schedule — timeline | Shows | Time grid | ✅ | ✅ | — |
| 6. Schedule — timeline | Shows | Event duration blocks | ✅ | ✅ | — |
| 6. Schedule — timeline | Shows | Current-time indicator | ✅ | ✅ | — |
| 6. Schedule — timeline | Shows | Artist images and names | ✅ | ◐ | Android: Names only; no timeline images |
| 6. Schedule — timeline | Shows | Event times and tags | ✅ | ✅ | — |
| 6. Schedule — timeline | Shows | Artist origin and keywords | ✅ | ◐ | Android: Country text only; no keywords |
| 6. Schedule — timeline | Shows | Optional artist summaries | ✅ | ✅ | — |
| 6. Schedule — timeline | Shows | Personal ratings | ✅ | ✅ | — |
| 6. Schedule — timeline | Shows | Saved status | ✅ | ✅ | — |
| 6. Schedule — timeline | Shows | Friend attendance badges | ✅ | ☐ | Android: No friend profiles |
| 6. Schedule — timeline | Shows | Estimated-end-time notice | ✅ | ✅ | — |
| 6. Schedule — timeline | Actions | Select day | ✅ | ✅ | — |
| 6. Schedule — timeline | Actions | Scroll times and stages | ✅ | ✅ | — |
| 6. Schedule — timeline | Actions | Change timeline scale | ✅ | ✅ | iOS: pinch + three toolbar zoom presets; Android: Two-axis pinch + stage-width/time-scale sliders |
| 6. Schedule — timeline | Actions | Move to adjacent day | ✅ | ✅ | iOS: boundary-pull gesture; Android: Day tabs; no boundary-pull gesture |
| 6. Schedule — timeline | Actions | Filter: Saved | ✅ | ✅ | — |
| 6. Schedule — timeline | Actions | Filter: Optimal (when supported) | ✅ | ✅ | — |
| 6. Schedule — timeline | Actions | Filter: Favorites | ✅ | ✅ | — |
| 6. Schedule — timeline | Actions | Filter: All | ✅ | ✅ | — |
| 6. Schedule — timeline | Actions | Save / remove events | ✅ | ✅ | — |
| 6. Schedule — timeline | Actions | Open event preview | ✅ | ☐ | iOS: long press + context menu; Android: Long press opens action menu without preview |
| 6. Schedule — timeline | Actions | Read end-time explanation | ✅ | ✅ | — |
| 6. Schedule — timeline | Navigation | Event → highlighted artist details | ✅ | ✅ | — |
| 6. Schedule — timeline | Navigation | Stage header → stage details | ✅ | ✅ | — |
| 6. Schedule — timeline | Navigation | Stage actions → external map | ✅ | ☐ | iOS: context menu, Apple Maps; Android: Stage headers navigate only; directions in place details |
| 6. Schedule — timeline | Navigation | View toggle → schedule list | ✅ | ✅ | — |
| 6. Schedule — timeline | Navigation | Toolbar → My plan | ✅ | ☐ | iOS: leading calendar icon; Android: saved/optimal filters |
| 6. Schedule — timeline | Navigation | Open unplaced events | ✅ | ✅ | iOS: sheet; Android: Count button → ModalBottomSheet |
| 6. Schedule — timeline | Shows | Unreachable-next-concert warning | ☐ | ✅ | iOS: no transition-warning cell; Android: saved/optimal plans; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Timeline.kt) |
| 6. Schedule — timeline | Actions | Adjust stage width without gestures | ✅ | ✅ | iOS: three presets; both axes together; Android: stage-width slider; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt) |
| 6. Schedule — timeline | Actions | Adjust time scale without gestures | ✅ | ✅ | iOS: three presets; both axes together; Android: time-scale slider; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt) |
| 6. Schedule — timeline | Actions | Reset timeline zoom | ✅ | ✅ | iOS: toolbar-menu reset; Android: zoom-dialog reset; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt) |
| 6. Schedule — timeline | Actions | Rate artist from timeline | ☐ | ✅ | iOS: save-only context menu; Android: rating-sheet action; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Timeline.kt) |
| 7. Schedule — list | Shows | Selected-day events | ✅ | ✅ | Android: List with unknown-time/date sections; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt) |
| 7. Schedule — list | Shows | Event times and tags | ✅ | ◐ | Android: Times only; EventRow omits tags |
| 7. Schedule — list | Shows | Artist images and names | ✅ | ◐ | Android: Names only; no event-row photos |
| 7. Schedule — list | Shows | Stage names | ✅ | ✅ | — |
| 7. Schedule — list | Shows | Personal ratings | ✅ | ☐ | Android: EventRow omits artist rating |
| 7. Schedule — list | Shows | Saved status | ✅ | ✅ | — |
| 7. Schedule — list | Shows | Friend attendance indicators | ✅ | ☐ | Android: No friend profiles |
| 7. Schedule — list | Shows | Empty-results message | ✅ | ✅ | — |
| 7. Schedule — list | Actions | Select day | ✅ | ✅ | — |
| 7. Schedule — list | Actions | Filter: Saved | ✅ | ✅ | — |
| 7. Schedule — list | Actions | Filter: Optimal (when supported) | ✅ | ✅ | — |
| 7. Schedule — list | Actions | Filter: Favorites | ✅ | ✅ | — |
| 7. Schedule — list | Actions | Filter: All | ✅ | ✅ | — |
| 7. Schedule — list | Actions | Save / remove events | ✅ | ✅ | — |
| 7. Schedule — list | Actions | Open event preview | ✅ | ☐ | iOS: long press + context menu; Android: EventRow has navigation/bookmark only |
| 7. Schedule — list | Navigation | Event → highlighted artist details | ✅ | ✅ | — |
| 7. Schedule — list | Navigation | View toggle → timeline | ✅ | ✅ | — |
| 7. Schedule — list | Navigation | Toolbar → My plan | ✅ | ☐ | iOS: leading calendar icon; saved/optimal list; Android: saved/optimal filters |
| 7. Schedule — list | Navigation | Open unplaced events | ✅ | ✅ | iOS: sheet; Android: Unknown-time/date sections inline; no separate list sheet |
| 7. Schedule — list | Shows | Walking time between concerts | ✅ | ✅ | iOS: My plan → saved/optimal list; Android: saved/optimal plans; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt) |
| 7. Schedule — list | Shows | Walking distance between concerts | ✅ | ✅ | iOS: My plan → saved/optimal list; Android: saved/optimal plans; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt) |
| 7. Schedule — list | Shows | Unreachable-next-concert warning | ✅ | ✅ | iOS: My plan → saved/optimal list; Android: saved/optimal plans; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt) |
| 7. Schedule — list | Shows | Unknown walking-time label | ✅ | ✅ | iOS: My plan → saved/optimal list; Android: unavailable transfer label; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt) |
| 8. Unplaced events | Shows | Events without timeline placement | ✅ | ✅ | iOS: sheet; Android: Timeline sheet / inline list sections; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Timeline.kt) |
| 8. Unplaced events | Shows | Unknown-time labels | ✅ | ✅ | — |
| 8. Unplaced events | Shows | Unknown-date labels | ✅ | ◐ | Android: List has date-unknown section; timeline sheet has time heading only |
| 8. Unplaced events | Shows | Event count (entry button) | ✅ | ✅ | — |
| 8. Unplaced events | Actions | Browse events | ✅ | ✅ | — |
| 8. Unplaced events | Actions | Save / remove events | ✅ | ✅ | — |
| 8. Unplaced events | Actions | Open event preview | ✅ | ☐ | iOS: long press + context menu; Android: No preview in unplaced EventRow |
| 8. Unplaced events | Navigation | Event → highlighted artist details | ✅ | ✅ | — |
| 8. Unplaced events | Navigation | Open related details | ✅ | ✅ | iOS: navigation inside sheet; Android: Artist and stage routes outside sheet |
| 8. Unplaced events | Navigation | Return to Schedule | ✅ | ✅ | iOS: Done closes sheet; Android: Sheet dismiss / Back; inline list sections also available |
| 9. Artists / Favorites — list or grid | Shows | Artist catalog / favorites subset | ✅ | ✅ | Android: Search + grouping filter sheet + adaptive grid/list; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 9. Artists / Favorites — list or grid | Shows | Artist images and names | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Shows | Personal ratings | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Shows | Alternative rating markers | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Shows | Friend rating indicators | ✅ | ☐ | Android: No friend profiles |
| 9. Artists / Favorites — list or grid | Shows | Empty / no-match messages | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Actions | Search artists | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Actions | Toggle favorites-only mode | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Actions | Filter artist groupings | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Actions | Clear filters | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Actions | Choose list layout | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Actions | Choose comfortable grid | ✅ | ✅ | Android: One adaptive grid; no density selector |
| 9. Artists / Favorites — list or grid | Actions | Choose compact grid | ✅ | ☐ | Android: No second grid density |
| 9. Artists / Favorites — list or grid | Navigation | Artist → artist details | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Navigation | Globe → artist world map | ✅ | ✅ | — |
| 9. Artists / Favorites — list or grid | Navigation | Categories → program discovery | ✅ | ☐ | Android: Category entry points in More, not Artists |
| 9. Artists / Favorites — list or grid | Shows | Filtered artist count | ☐ | ✅ | iOS: no catalog count; Android: browse header; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 9. Artists / Favorites — list or grid | Actions | Rate directly from artist catalog | ☐ | ✅ | iOS: detail-only rating; Android: button/long press; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 9. Artists / Favorites — list or grid | Actions | Refresh program from artist catalog | ☐ | ✅ | iOS: Data & Sync refresh; Android: pull to refresh; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 9. Artists / Favorites — list or grid | Actions | Reset search, favorites, filters together | ☐ | ✅ | iOS: separate controls; Android: empty-results reset; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 10. Artist world map | Shows | Represented countries | ✅ | ✅ | iOS: map page; Android: Native globe + visible country list; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt) |
| 10. Artist world map | Shows | Artist-count country shading | ✅ | ◐ | Android: Binary represented-country fill; counts in visible list |
| 10. Artist world map | Shows | Selected-country highlight | ✅ | ☐ | Android: Country selection navigates immediately |
| 10. Artist world map | Shows | Map-loading indicator | ✅ | ✅ | — |
| 10. Artist world map | Shows | Map-loading failure | ✅ | ☐ | Android: No explicit globe failure/empty UI |
| 10. Artist world map | Shows | Missing-country-data message | ✅ | ☐ | Android: No explicit globe failure/empty UI |
| 10. Artist world map | Actions | Pan and zoom | ✅ | ✅ | — |
| 10. Artist world map | Actions | Switch globe / flat map | ✅ | ☐ | Android: Globe only |
| 10. Artist world map | Actions | Select represented country | ✅ | ✅ | — |
| 10. Artist world map | Actions | Expand country artist list | ✅ | ☐ | iOS: sheet heights; Android: Country is a separate page, no expanding sheet |
| 10. Artist world map | Navigation | Country → country artist list | ✅ | ✅ | iOS: sheet; Android: Globe tap / visible country list → CountryScreen |
| 10. Artist world map | Navigation | Artist → artist details | ✅ | ◐ | Android: Via country page; no artist sheet over globe |
| 10. Artist world map | Navigation | Back → artist catalog | ✅ | ✅ | — |
| 10. Artist world map | Shows | Visible country-and-count list | ☐ | ✅ | iOS: screen-reader country actions only; Android: visible list; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt) |
| 10. Artist world map | Actions | Reset globe orientation and zoom | ☐ | ✅ | iOS: projection toggle only; Android: reset control; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Globe.kt) |
| 11. Artists from one country | Shows | Country name and flag | ✅ | ◐ | iOS: page / map sheet; Android: Dedicated list page; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt); Android: Country title; flags in artist rows, not country title |
| 11. Artists from one country | Shows | Artist count | ✅ | ☐ | Android: Counts on globe list only, not CountryScreen |
| 11. Artists from one country | Shows | Country artist list | ✅ | ✅ | — |
| 11. Artists from one country | Shows | Artist images | ✅ | ✅ | — |
| 11. Artists from one country | Shows | Personal / friend rating indicators | ✅ | ◐ | Android: Personal ratings only |
| 11. Artists from one country | Shows | Country outline preview | ✅ | ☐ | iOS: standalone page only; Android: No outline on country page |
| 11. Artists from one country | Actions | Browse artists | ✅ | ✅ | — |
| 11. Artists from one country | Actions | Switch grid / list | ✅ | ☐ | Android: CountryScreen uses list only |
| 11. Artists from one country | Navigation | Artist → artist details | ✅ | ✅ | — |
| 11. Artists from one country | Navigation | Close country details → map | ✅ | ✅ | iOS: sheet dismissal; Android: Back → globe when opened from globe |
| 11. Artists from one country | Navigation | Back → preceding detail page | ✅ | ✅ | — |
| 11. Artists from one country | Actions | Rate directly from country list | ☐ | ✅ | iOS: detail-only rating; Android: row rating button; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 12. Artist detail | Shows | Artist name and photo | ✅ | ✅ | Android: Artist page; per-event editorial content inline; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 12. Artist detail | Shows | Country labels | ✅ | ✅ | — |
| 12. Artist detail | Shows | Personal rating / marker | ✅ | ✅ | — |
| 12. Artist detail | Shows | Friend rating indicators | ✅ | ☐ | Android: No friend profiles |
| 12. Artist detail | Shows | Optional AI summary | ✅ | ✅ | — |
| 12. Artist detail | Shows | Private note | ✅ | ✅ | — |
| 12. Artist detail | Shows | Artist description | ✅ | ✅ | — |
| 12. Artist detail | Shows | Performances | ✅ | ✅ | — |
| 12. Artist detail | Shows | Performance dates and times | ✅ | ✅ | — |
| 12. Artist detail | Shows | Stage names | ✅ | ✅ | — |
| 12. Artist detail | Shows | Saved performance status | ✅ | ✅ | — |
| 12. Artist detail | Shows | Friend attendance | ✅ | ☐ | Android: No friend profiles |
| 12. Artist detail | Shows | Saved-event conflicts | ✅ | ✅ | — |
| 12. Artist detail | Shows | Similar artists | ✅ | ✅ | — |
| 12. Artist detail | Shows | Website / social / music links | ✅ | ✅ | — |
| 12. Artist detail | Shows | Apple Music preview | ✅ | ✅ | — |
| 12. Artist detail | Shows | YouTube video | ✅ | ◐ | Android: Thumbnail + external video link; no embedded player |
| 12. Artist detail | Actions | Set / reset rating | ✅ | ✅ | — |
| 12. Artist detail | Actions | Choose alternative marker | ✅ | ✅ | — |
| 12. Artist detail | Actions | Add / edit private note | ✅ | ✅ | — |
| 12. Artist detail | Actions | Save / remove performances | ✅ | ✅ | — |
| 12. Artist detail | Actions | Play / pause music preview | ✅ | ✅ | — |
| 12. Artist detail | Actions | Load / play video | ✅ | ◐ | Android: External video app/browser only |
| 12. Artist detail | Actions | Share supported artist link | ✅ | ✅ | — |
| 12. Artist detail | Navigation | Photo → image viewer | ✅ | ✅ | iOS: full-screen viewer |
| 12. Artist detail | Navigation | Country → country artist list | ✅ | ✅ | — |
| 12. Artist detail | Navigation | Performance → stage details | ✅ | ✅ | — |
| 12. Artist detail | Navigation | Similar artist → artist details | ✅ | ✅ | — |
| 12. Artist detail | Navigation | Conflict → conflicting artist | ✅ | ☐ | iOS: event context menu; Android: Conflict names are text, not links |
| 12. Artist detail | Navigation | Website → in-app browser | ✅ | ◐ | Android: ACTION_VIEW external handler; no Custom Tabs/WebView |
| 12. Artist detail | Navigation | Social / music → app / browser | ✅ | ✅ | — |
| 12. Artist detail | Navigation | Open system sharing | ✅ | ✅ | iOS: share sheet; Android: ACTION_SEND chooser |
| 12. Artist detail | Actions | Jump to highlighted performance | ☐ | ✅ | iOS: highlight only; Android: scroll-to-concert action; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 12. Artist detail | Actions | Select / copy artist description | ☐ | ✅ | iOS: non-selectable description; Android: SelectionContainer; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 12. Artist detail | Navigation | Genre → genre artist list | ☐ | ✅ | iOS: global genre filter only; Android: independent genre page; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 12. Artist detail | Navigation | Performance category → category details | ☐ | ✅ | iOS: category overview entry; Android: inline event-tag chips; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt) |
| 13. Artist rating selector | Shows | Current rating | ✅ | ✅ | iOS: popover; Android: Modal bottom sheet; returns to invoking page/list; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/ArtistActions.kt) |
| 13. Artist rating selector | Shows | Three positive rating levels | ✅ | ✅ | — |
| 13. Artist rating selector | Shows | Thumbs-down marker | ✅ | ✅ | — |
| 13. Artist rating selector | Shows | Question-mark marker | ✅ | ✅ | — |
| 13. Artist rating selector | Shows | Warning marker | ✅ | ✅ | — |
| 13. Artist rating selector | Shows | Revisit marker | ✅ | ✅ | — |
| 13. Artist rating selector | Shows | Sleep markers | ✅ | ✅ | — |
| 13. Artist rating selector | Actions | Choose positive rating | ✅ | ✅ | — |
| 13. Artist rating selector | Actions | Choose alternative marker | ✅ | ✅ | — |
| 13. Artist rating selector | Actions | Reset rating | ✅ | ✅ | — |
| 13. Artist rating selector | Navigation | Selection → artist details | ✅ | ✅ | Android: Dismisses to invoking artist page/list |
| 13. Artist rating selector | Navigation | Dismiss → artist details | ✅ | ✅ | Android: Dismisses to invoking artist page/list |
| 14. Artist note editor | Shows | Private note text | ✅ | ✅ | iOS: sheet; Android: Text-input AlertDialog + discard confirmation; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/ArtistActions.kt) |
| 14. Artist note editor | Shows | Empty-note placeholder | ✅ | ✅ | — |
| 14. Artist note editor | Shows | Sync warning (when relevant) | ✅ | ☐ | Android: Local notes only; no cloud sync |
| 14. Artist note editor | Actions | Write / edit note | ✅ | ✅ | — |
| 14. Artist note editor | Actions | Clear note | ✅ | ✅ | — |
| 14. Artist note editor | Actions | Save note | ✅ | ✅ | — |
| 14. Artist note editor | Actions | Cancel editing | ✅ | ✅ | — |
| 14. Artist note editor | Actions | Discard / continue after cancellation | ✅ | ✅ | — |
| 14. Artist note editor | Navigation | Save → artist details | ✅ | ✅ | — |
| 14. Artist note editor | Navigation | Cancel → artist details | ✅ | ✅ | — |
| 15. Artist image viewer | Shows | Full artist photo | ✅ | ✅ | iOS: full-screen viewer; Android: Full-screen Dialog; pinch/pan + reset/close; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Design.kt) |
| 15. Artist image viewer | Shows | Loading indicator | ✅ | ✅ | — |
| 15. Artist image viewer | Shows | Image-unavailable message | ✅ | ◐ | Android: Generic image placeholder icon; no failure text |
| 15. Artist image viewer | Actions | Zoom and pan | ✅ | ✅ | — |
| 15. Artist image viewer | Actions | Show / hide image controls | ✅ | ☐ | iOS: tap image; Android: Reset/close controls always visible |
| 15. Artist image viewer | Actions | Dismiss image viewer | ✅ | ✅ | iOS: viewer gesture; Android: Dialog Back / explicit close; no swipe dismissal |
| 15. Artist image viewer | Navigation | Close / dismiss → artist details | ✅ | ✅ | — |
| 16. Program discovery — category overview | Shows | Category entries | ✅ | ✅ | iOS: category tiles; Android: Category list integrated into More; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt); Android: More contains category rows rather than tiles |
| 16. Program discovery — category overview | Shows | Category titles | ✅ | ✅ | — |
| 16. Program discovery — category overview | Shows | Event counts | ✅ | ☐ | Android: No category counts or dedicated empty message |
| 16. Program discovery — category overview | Shows | Empty-category message | ✅ | ☐ | Android: No category counts or dedicated empty message |
| 16. Program discovery — category overview | Actions | Browse categories | ✅ | ✅ | — |
| 16. Program discovery — category overview | Navigation | Category → category detail | ✅ | ✅ | — |
| 16. Program discovery — category overview | Navigation | Back → Artists | ✅ | ◐ | Android: Overview integrated into More, not an Artists subpage |
| 17. Program discovery — category detail | Shows | Category introduction | ✅ | ✅ | Android: TagScreen with flat event list; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt) |
| 17. Program discovery — category detail | Shows | Optional editorial text | ✅ | ✅ | — |
| 17. Program discovery — category detail | Shows | Labelled information fields | ✅ | ✅ | — |
| 17. Program discovery — category detail | Shows | Related links | ✅ | ✅ | — |
| 17. Program discovery — category detail | Shows | Events grouped by date | ✅ | ☐ | Android: Flat event list with per-row dates |
| 17. Program discovery — category detail | Shows | Event times | ✅ | ✅ | — |
| 17. Program discovery — category detail | Shows | Artists and stages | ✅ | ✅ | — |
| 17. Program discovery — category detail | Shows | Personal / friend indicators | ✅ | ◐ | Android: Saved bookmark only; no ratings/friends |
| 17. Program discovery — category detail | Shows | Unknown-date labels | ✅ | ✅ | — |
| 17. Program discovery — category detail | Shows | Empty-results message | ✅ | ☐ | Android: No empty-event message in TagScreen |
| 17. Program discovery — category detail | Actions | Read category information | ✅ | ✅ | — |
| 17. Program discovery — category detail | Actions | Browse events | ✅ | ✅ | — |
| 17. Program discovery — category detail | Actions | Save / remove events | ✅ | ✅ | — |
| 17. Program discovery — category detail | Actions | Open event preview | ✅ | ☐ | iOS: long press + context menu; Android: No EventRow preview |
| 17. Program discovery — category detail | Navigation | Feature-enabled festival: event → event details | ✅ | ✅ | All events use concert details, including events without extra content |
| 17. Program discovery — category detail | Navigation | Festival without concert details: event → highlighted artist | ✅ | ✅ | Default; personal “Always show concert detail pages” preference overrides this route |
| 17. Program discovery — category detail | Navigation | Editorial links → page / website | ✅ | ✅ | — |
| 17. Program discovery — category detail | Navigation | Back → category overview | ✅ | ✅ | Android: Back → More category rows |
| 18. Editorial event detail | Shows | Event summary | ✅ | ✅ | Centered hero with scalable time badge, stage number and artist avatar; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/ConcertDetail.kt) |
| 18. Editorial event detail | Shows | Date and time | ✅ | ✅ | — |
| 18. Editorial event detail | Settings | Always show concert detail pages | ✅ | ✅ | Defaults off; applies across editions and does not enable festival editorial data |
| 18. Editorial event detail | Shows | Unknown-date state | ✅ | ✅ | — |
| 18. Editorial event detail | Shows | Editorial description | ✅ | ✅ | Optional content owned by the festival eventDetails feature |
| 18. Editorial event detail | Shows | Labelled information fields | ✅ | ✅ | — |
| 18. Editorial event detail | Shows | Related links | ✅ | ✅ | — |
| 18. Editorial event detail | Actions | Save / remove event | ✅ | ✅ | — |
| 18. Editorial event detail | Shows | Artist has stronger typography than stage | ✅ | ✅ | Without duplicated large artist photo |
| 18. Editorial event detail | Actions | Select / copy editorial text | ✅ | ✅ | — |
| 18. Editorial event detail | Shows | Artist avatar and name | ✅ | ✅ | Header link opens highlighted artist details |
| 18. Editorial event detail | Navigation | Stage header → stage details | ✅ | ✅ | Selected concert retained |
| 18. Editorial event detail | Navigation | Open large stage map | ✅ | ✅ | Map preview and explicit map action |
| 18. Editorial event detail | Navigation | Editorial links → page / website | ✅ | ✅ | — |
| 18. Editorial event detail | Navigation | Return to previous context | ✅ | ✅ | iOS: back navigation |
| 19. Friends — setup state | Shows | Setup instructions | ✅ | ☐ | iOS: setup state; Android: No friends, sharing, or profile-badge UI; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 19. Friends — setup state | Shows | Profile badge name | ✅ | ☐ | — |
| 19. Friends — setup state | Shows | Badge colour | ✅ | ☐ | — |
| 19. Friends — setup state | Shows | Badge readiness | ✅ | ☐ | — |
| 19. Friends — setup state | Shows | Sync-service availability / errors | ✅ | ☐ | iOS: iCloud |
| 19. Friends — setup state | Shows | Archive / experimental sharing restrictions | ✅ | ☐ | — |
| 19. Friends — setup state | Actions | Enter display name | ✅ | ☐ | — |
| 19. Friends — setup state | Actions | Select badge colour | ✅ | ☐ | — |
| 19. Friends — setup state | Actions | Save badge | ✅ | ☐ | — |
| 19. Friends — setup state | Actions | Retry sync-service check | ✅ | ☐ | iOS: iCloud |
| 19. Friends — setup state | Navigation | Colour → colour picker | ✅ | ☐ | — |
| 19. Friends — setup state | Navigation | Setup complete → connected Friends | ✅ | ☐ | — |
| 20. Friends — connected state | Shows | Personal profile badge | ✅ | ☐ | iOS: connected state; Android: No friends, sharing, or profile-badge UI; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 20. Friends — connected state | Shows | Privacy summary | ✅ | ☐ | — |
| 20. Friends — connected state | Shows | Friend-based artist recommendations | ✅ | ☐ | — |
| 20. Friends — connected state | Shows | Followed profiles | ✅ | ☐ | — |
| 20. Friends — connected state | Shows | Profile activity summaries | ✅ | ☐ | — |
| 20. Friends — connected state | Shows | Follower count | ✅ | ☐ | — |
| 20. Friends — connected state | Shows | Connection guidance / empty states | ✅ | ☐ | — |
| 20. Friends — connected state | Actions | Browse recommendation cards | ✅ | ☐ | — |
| 20. Friends — connected state | Actions | Browse followed profiles | ✅ | ☐ | — |
| 20. Friends — connected state | Actions | Open connection menu | ✅ | ☐ | — |
| 20. Friends — connected state | Actions | Add / invite friends | ✅ | ☐ | — |
| 20. Friends — connected state | Navigation | Badge → badge editor | ✅ | ☐ | — |
| 20. Friends — connected state | Navigation | Recommendations → full list | ✅ | ☐ | — |
| 20. Friends — connected state | Navigation | Recommendation → artist details | ✅ | ☐ | — |
| 20. Friends — connected state | Navigation | Followed profile → profile details | ✅ | ☐ | — |
| 20. Friends — connected state | Navigation | Connection menu → QR scanner | ✅ | ☐ | — |
| 20. Friends — connected state | Navigation | Connection menu → own QR code | ✅ | ☐ | — |
| 20. Friends — connected state | Navigation | Connection menu → invitation link | ✅ | ☐ | — |
| 20. Friends — connected state | Navigation | Follower details → sharing management | ✅ | ☐ | — |
| 21. Profile badge editor | Shows | Current display name | ✅ | ☐ | iOS: sheet; Android: No friends, sharing, or profile-badge UI; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 21. Profile badge editor | Shows | Current badge colour | ✅ | ☐ | — |
| 21. Profile badge editor | Shows | Badge preview | ✅ | ☐ | — |
| 21. Profile badge editor | Shows | Explanatory text | ✅ | ☐ | — |
| 21. Profile badge editor | Actions | Edit display name | ✅ | ☐ | — |
| 21. Profile badge editor | Actions | Choose colour | ✅ | ☐ | — |
| 21. Profile badge editor | Actions | Save valid changes | ✅ | ☐ | — |
| 21. Profile badge editor | Actions | Cancel editing | ✅ | ☐ | — |
| 21. Profile badge editor | Navigation | Colour → colour picker | ✅ | ☐ | — |
| 21. Profile badge editor | Navigation | Save / cancel → Friends | ✅ | ☐ | — |
| 22. Badge colour selector | Shows | Badge colour palette | ✅ | ☐ | iOS: popover; Android: No friends, sharing, or profile-badge UI; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 22. Badge colour selector | Shows | Current colour selection | ✅ | ☐ | — |
| 22. Badge colour selector | Actions | Select colour | ✅ | ☐ | — |
| 22. Badge colour selector | Navigation | Selection → setup / badge editor | ✅ | ☐ | — |
| 23. My invitation QR code | Shows | One-time invitation QR code | ✅ | ☐ | iOS: sheet; Android: No friends, sharing, or profile-badge UI; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 23. My invitation QR code | Shows | Connection instructions | ✅ | ☐ | — |
| 23. My invitation QR code | Shows | Privacy information | ✅ | ☐ | — |
| 23. My invitation QR code | Shows | Preparation indicator | ✅ | ☐ | — |
| 23. My invitation QR code | Shows | Preparation errors | ✅ | ☐ | — |
| 23. My invitation QR code | Actions | Present code for scanning | ✅ | ☐ | — |
| 23. My invitation QR code | Actions | Generate new code | ✅ | ☐ | — |
| 23. My invitation QR code | Actions | Retry preparation | ✅ | ☐ | — |
| 23. My invitation QR code | Navigation | Return to Friends | ✅ | ☐ | iOS: Done closes sheet |
| 24. Scan friend QR code | Shows | Camera preview | ✅ | ☐ | iOS: camera sheet; Android: No friends, sharing, or profile-badge UI; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 24. Scan friend QR code | Shows | Scanning instructions | ✅ | ☐ | — |
| 24. Scan friend QR code | Shows | Invitation-acceptance progress | ✅ | ☐ | — |
| 24. Scan friend QR code | Shows | Camera-permission status | ✅ | ☐ | — |
| 24. Scan friend QR code | Shows | Scan errors | ✅ | ☐ | — |
| 24. Scan friend QR code | Actions | Grant camera permission | ✅ | ☐ | — |
| 24. Scan friend QR code | Actions | Scan invitation | ✅ | ☐ | — |
| 24. Scan friend QR code | Actions | Retry after error | ✅ | ☐ | — |
| 24. Scan friend QR code | Navigation | Successful scan → Friends | ✅ | ☐ | — |
| 24. Scan friend QR code | Navigation | Return to Friends | ✅ | ☐ | iOS: Done closes sheet |
| 24. Scan friend QR code | Navigation | Camera access → app settings | ✅ | ☐ | iOS: app Settings |
| 25. Share invitation link | Shows | Sharing privacy information | ✅ | ☐ | iOS: invitation sheet; Android: No friends, sharing, or profile-badge UI; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 25. Share invitation link | Shows | One-time invitation link | ✅ | ☐ | — |
| 25. Share invitation link | Shows | Preparation indicator | ✅ | ☐ | — |
| 25. Share invitation link | Shows | Preparation errors | ✅ | ☐ | — |
| 25. Share invitation link | Actions | Share invitation link | ✅ | ☐ | — |
| 25. Share invitation link | Actions | Retry link preparation | ✅ | ☐ | — |
| 25. Share invitation link | Navigation | Open system sharing | ✅ | ☐ | iOS: share sheet |
| 25. Share invitation link | Navigation | Return to Friends | ✅ | ☐ | iOS: Done closes sheet |
| 26. Manage profile sharing | Shows | Profile-sharing management interface | ✅ | ☐ | iOS: CloudKit system sheet; Android: No friends, sharing, or profile-badge UI; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 26. Manage profile sharing | Shows | Shared festival profile | ✅ | ☐ | — |
| 26. Manage profile sharing | Shows | Sharing participants | ✅ | ☐ | — |
| 26. Manage profile sharing | Shows | Private, read-only access | ✅ | ☐ | — |
| 26. Manage profile sharing | Actions | Manage participants | ✅ | ☐ | — |
| 26. Manage profile sharing | Actions | Manage profile sharing | ✅ | ☐ | — |
| 26. Manage profile sharing | Navigation | Dismiss → Friends | ✅ | ☐ | — |
| 26. Manage profile sharing | Navigation | Refreshed participant information | ✅ | ☐ | — |
| 27. Friend's shared profile | Shows | Friend badge and name | ✅ | ☐ | Android: No friends, sharing, or profile-badge UI; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 27. Friend's shared profile | Shows | Saved events by day | ✅ | ☐ | — |
| 27. Friend's shared profile | Shows | Artist ratings | ✅ | ☐ | — |
| 27. Friend's shared profile | Shows | Alternative rating markers | ✅ | ☐ | — |
| 27. Friend's shared profile | Shows | Shared saved-event indicators | ✅ | ☐ | — |
| 27. Friend's shared profile | Shows | Empty-event / rating messages | ✅ | ☐ | — |
| 27. Friend's shared profile | Actions | Browse saved program | ✅ | ☐ | — |
| 27. Friend's shared profile | Actions | Browse rated artists | ✅ | ☐ | — |
| 27. Friend's shared profile | Navigation | Saved event → highlighted artist | ✅ | ☐ | — |
| 27. Friend's shared profile | Navigation | Rated artist → artist details | ✅ | ☐ | — |
| 27. Friend's shared profile | Navigation | Back → Friends | ✅ | ☐ | — |
| 28. Recommendations from friends — full list | Shows | Recommended artists | ✅ | ☐ | Android: No friends, sharing, or profile-badge UI; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 28. Recommendations from friends — full list | Shows | Artist images | ✅ | ☐ | — |
| 28. Recommendations from friends — full list | Shows | Genre information | ✅ | ☐ | — |
| 28. Recommendations from friends — full list | Shows | Country information | ✅ | ☐ | — |
| 28. Recommendations from friends — full list | Shows | Contributing friends | ✅ | ☐ | — |
| 28. Recommendations from friends — full list | Shows | Friend ratings / saved performances | ✅ | ☐ | — |
| 28. Recommendations from friends — full list | Actions | Browse recommendations | ✅ | ☐ | — |
| 28. Recommendations from friends — full list | Navigation | Recommendation → artist details | ✅ | ☐ | — |
| 28. Recommendations from friends — full list | Navigation | Relevant performance highlighted | ✅ | ☐ | — |
| 28. Recommendations from friends — full list | Navigation | Back → Friends | ✅ | ☐ | — |
| 29. More | Shows | Available feature links | ✅ | ✅ | Android: Settings, globe, Information, categories, About, Licenses; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt) |
| 29. More | Shows | Available festival information pages | ✅ | ✅ | — |
| 29. More | Actions | Choose entry | ✅ | ✅ | — |
| 29. More | Navigation | News (when supported) | ✅ | ◐ | Android: News is a primary destination; no More entry |
| 29. More | Navigation | Park & Ride (current Rudolstadt) | ✅ | ✅ | — |
| 29. More | Navigation | Bus (current Rudolstadt) | ✅ | ✅ | — |
| 29. More | Navigation | About | ✅ | ✅ | — |
| 29. More | Navigation | Donations | ✅ | ☐ | Android: No donation screen |
| 29. More | Navigation | Settings | ✅ | ✅ | — |
| 29. More | Navigation | Data & Sync (live editions) | ✅ | ◐ | Android: Data status via section title; no More sync entry |
| 30. News | Shows | Current-language articles | ✅ | ✅ | iOS: list / sheet; Android: Primary News destination with unread badge; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/News.kt) |
| 30. News | Shows | Headlines and excerpts | ✅ | ✅ | — |
| 30. News | Shows | Publication dates and times | ✅ | ✅ | — |
| 30. News | Shows | Unread indicators (Rudolstadt) | ✅ | ✅ | — |
| 30. News | Shows | Loading / empty / failure states | ✅ | ✅ | — |
| 30. News | Shows | Fallback notices | ✅ | ✅ | — |
| 30. News | Shows | Simpler list (other providers) | ✅ | ☐ | Android: Only current Rudolstadt news provider |
| 30. News | Actions | Refresh news (Rudolstadt) | ✅ | ✅ | iOS: overflow menu |
| 30. News | Actions | Refresh article list | ✅ | ✅ | iOS: pull-to-refresh, page only |
| 30. News | Actions | Toggle read / unread (Rudolstadt) | ✅ | ✅ | iOS: swipe action |
| 30. News | Actions | Mark all read (Rudolstadt) | ✅ | ✅ | — |
| 30. News | Actions | Confirm bulk read change | ✅ | ☐ | iOS: confirmation dialog; Android: Mark-all-read applies immediately |
| 30. News | Navigation | Article → news details | ✅ | ✅ | — |
| 30. News | Navigation | More → news list | ✅ | ◐ | Android: News primary destination, not a More link |
| 30. News | Navigation | Unread indicator → news | ✅ | ✅ | iOS: tab accessory + sheet; Android: Badge on News navigation item |
| 30. News | Navigation | Close news → previous context | ✅ | ◐ | iOS: sheet → previous tab; Android: primary destination; Back returns to Programme |
| 31. News detail | Shows | Headline and article | ✅ | ✅ | Android: News detail + related artist/place rows; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/News.kt) |
| 31. News detail | Shows | Publication date and time | ✅ | ✅ | — |
| 31. News detail | Shows | Article introduction | ✅ | ☐ | Android: Detail omits longDescription |
| 31. News detail | Shows | Detected links | ✅ | ◐ | Android: HTML links only; no plain-text URL detection |
| 31. News detail | Shows | Optional YouTube previews | ✅ | ☐ | Android: No news-video detection or player |
| 31. News detail | Shows | Related artists and stages | ✅ | ✅ | — |
| 31. News detail | Shows | Provider-specific related links | ✅ | ◐ | Android: HTML links only; no provider link collection |
| 31. News detail | Actions | Read article | ✅ | ✅ | — |
| 31. News detail | Actions | Load / play video | ✅ | ☐ | Android: No news-video detection or player |
| 31. News detail | Actions | Follow article links | ✅ | ✅ | — |
| 31. News detail | Actions | Automatic read marking | ✅ | ✅ | — |
| 31. News detail | Navigation | Related artist → artist details | ✅ | ✅ | — |
| 31. News detail | Navigation | Artist mention → artist details | ✅ | ☐ | Android: Related artist rows only; no inline artist links |
| 31. News detail | Navigation | Related stage → stage details | ✅ | ✅ | — |
| 31. News detail | Navigation | Other links → destinations | ✅ | ✅ | — |
| 31. News detail | Navigation | Back → news list | ✅ | ✅ | — |
| 31. News detail | Navigation | Missing notification article → list | ✅ | ☐ | Android: Not-found state + retry; no list fallback |
| 32. Park & Ride — festival information page | Shows | Current Rudolstadt information | ✅ | ✅ | Android: Combined InformationScreen; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt); Android: Combined InformationScreen; also reachable in archives |
| 32. Park & Ride — festival information page | Shows | Arrival / navigation guidance | ✅ | ✅ | — |
| 32. Park & Ride — festival information page | Shows | Two parking locations | ✅ | ✅ | — |
| 32. Park & Ride — festival information page | Shows | Official festival source link | ✅ | ✅ | — |
| 32. Park & Ride — festival information page | Actions | Read arrival guidance | ✅ | ✅ | — |
| 32. Park & Ride — festival information page | Actions | Select parking location | ✅ | ✅ | — |
| 32. Park & Ride — festival information page | Actions | Select official source | ✅ | ✅ | — |
| 32. Park & Ride — festival information page | Navigation | Parking → place details | ✅ | ✅ | — |
| 32. Park & Ride — festival information page | Navigation | Source → festival website | ✅ | ✅ | — |
| 32. Park & Ride — festival information page | Navigation | Back → More | ✅ | ✅ | — |
| 33. Bus timetable | Shows | Current Rudolstadt timetable | ✅ | ◐ | iOS: embedded timetable; Android: External timetable link, no embedded page; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt); Android: Only link to external timetable |
| 33. Bus timetable | Shows | External KomBus widget | ✅ | ◐ | Android: External browser/app; not embedded |
| 33. Bus timetable | Shows | Service-dependent content | ✅ | ◐ | Android: External service content not rendered in app |
| 33. Bus timetable | Actions | Use widget controls | ✅ | ◐ | Android: External service only |
| 33. Bus timetable | Navigation | Widget links → destinations | ✅ | ◐ | Android: External service only |
| 33. Bus timetable | Navigation | Back → More | ✅ | ◐ | Android: External Back → Information → More |
| 34. About | Shows | Unofficial app information | ✅ | ✅ | Android: About page + contact/repository/festival links; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt) |
| 34. About | Shows | Official festival links | ✅ | ✅ | — |
| 34. About | Shows | Developer information | ✅ | ✅ | — |
| 34. About | Shows | Contact options | ✅ | ✅ | — |
| 34. About | Shows | Licensing introduction | ✅ | ☐ | Android: Licenses link only; no introductory license text |
| 34. About | Actions | Read app information | ✅ | ✅ | — |
| 34. About | Actions | Copy official links | ✅ | ☐ | Android: No copy controls/context menus |
| 34. About | Actions | Copy developer GitHub link | ✅ | ☐ | Android: No copy controls/context menus |
| 34. About | Actions | Copy email address | ✅ | ☐ | Android: No copy controls/context menus |
| 34. About | Navigation | Donations | ✅ | ☐ | Android: No donation screen |
| 34. About | Navigation | Licenses | ✅ | ✅ | — |
| 34. About | Navigation | Festival website | ✅ | ✅ | — |
| 34. About | Navigation | Official app listing | ✅ | ☐ | iOS: App Store link; Android: Apple listing filtered out; no Android-store listing |
| 34. About | Navigation | Developer GitHub page | ✅ | ◐ | Android: Opens app repository, not developer profile |
| 34. About | Navigation | Mail app | ✅ | ✅ | — |
| 34. About | Navigation | Back → More | ✅ | ✅ | — |
| 34. About | Navigation | Open app source repository | ☐ | ✅ | iOS: developer-profile link only; Android: repository link; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt) |
| 35. Donations | Shows | Support message | ✅ | ☐ | Android: No donation screen or billing flow; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt) |
| 35. Donations | Shows | Five donation options | ✅ | ☐ | — |
| 35. Donations | Shows | Localized purchase prices | ✅ | ☐ | iOS: App Store |
| 35. Donations | Shows | Explanatory / disclaimer text | ✅ | ☐ | — |
| 35. Donations | Shows | Product-loading indicator | ✅ | ☐ | — |
| 35. Donations | Actions | Choose donation amount | ✅ | ☐ | — |
| 35. Donations | Actions | Start in-app purchase | ✅ | ☐ | — |
| 35. Donations | Navigation | Open platform purchase flow | ✅ | ☐ | iOS: App Store |
| 35. Donations | Navigation | Back → More / About | ✅ | ☐ | — |
| 36. Licenses — list | Shows | Third-party libraries | ✅ | ✅ | Android: Flat license/source link list; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt) |
| 36. Licenses — list | Shows | Data-source acknowledgements | ✅ | ✅ | — |
| 36. Licenses — list | Shows | License names | ✅ | ✅ | — |
| 36. Licenses — list | Shows | Library / data-source groups | ✅ | ☐ | Android: Single flat list |
| 36. Licenses — list | Actions | Browse entries | ✅ | ✅ | — |
| 36. Licenses — list | Navigation | Entry → license detail | ✅ | ◐ | Android: External license/source URL; no native detail page |
| 36. Licenses — list | Navigation | Back → About | ✅ | ✅ | — |
| 37. License detail | Shows | Component / source name | ✅ | ◐ | Android: External license/source URLs, no native details; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt); Android: External source/license page only; no in-app detail viewer |
| 37. License detail | Shows | License type | ✅ | ◐ | Android: External source/license page only; no in-app detail viewer |
| 37. License detail | Shows | Copyright | ✅ | ◐ | Android: External source/license page only; no in-app detail viewer |
| 37. License detail | Shows | Explanatory notes | ✅ | ☐ | Android: No app-specific license detail notes |
| 37. License detail | Shows | Full license text (where applicable) | ✅ | ◐ | Android: External source/license page only; no in-app detail viewer |
| 37. License detail | Actions | Read license | ✅ | ◐ | Android: External source/license page only; no in-app detail viewer |
| 37. License detail | Actions | Select / copy license text | ✅ | ◐ | Android: External source/license page only; no in-app detail viewer |
| 37. License detail | Navigation | Repository / source website | ✅ | ◐ | Android: External source/license page only; no in-app detail viewer |
| 37. License detail | Navigation | Back → license list | ✅ | ✅ | Android: System Back from external handler |
| 38. Settings | Shows | Selected festival / edition | ✅ | ✅ | Android: Edition, appearance, notification, language controls; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt) |
| 38. Settings | Shows | Current / archive / experimental explanation | ✅ | ✅ | — |
| 38. Settings | Shows | Notification status (news supported) | ✅ | ◐ | Android: Stored preference shown; external permission changes not rechecked |
| 38. Settings | Shows | Schedule day-selector preference | ✅ | ☐ | Android: No setting; fixed scrollable day tabs |
| 38. Settings | Shows | AI-summary preference (when supported) | ✅ | ✅ | — |
| 38. Settings | Shows | Rating-symbol preference | ✅ | ✅ | — |
| 38. Settings | Shows | Language-settings link | ✅ | ✅ | — |
| 38. Settings | Actions | Switch festival / year | ✅ | ✅ | — |
| 38. Settings | Actions | Choose compact day selector | ✅ | ☐ | iOS: toolbar menu; Android: No compact day-menu mode |
| 38. Settings | Actions | Choose day-tab selector | ✅ | ◐ | iOS: segmented day tabs; Android: Day tabs always used; no selector-style setting |
| 38. Settings | Actions | Toggle AI summaries | ✅ | ◐ | Android: Artist details honour toggle; timeline does not check setting |
| 38. Settings | Actions | Choose hearts / flames | ✅ | ✅ | — |
| 38. Settings | Actions | Activate news notifications | ✅ | ✅ | — |
| 38. Settings | Navigation | Switch edition content | ✅ | ✅ | iOS: root reload |
| 38. Settings | Navigation | Open notification settings | ✅ | ✅ | iOS: app Settings |
| 38. Settings | Navigation | Open app-language settings | ✅ | ✅ | iOS: app Settings |
| 38. Settings | Navigation | Back → More | ✅ | ✅ | — |
| 38. Settings | Navigation | Return to loading failure | ✅ | ☐ | iOS: close Settings sheet; Android: Settings unavailable while content gate fails |
| 38. Settings | Actions | Choose system-following app theme | ☐ | ✅ | iOS: follows system automatically; Android: explicit theme option; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt) |
| 38. Settings | Actions | Choose light app theme | ☐ | ✅ | iOS: no app override; Android: Light selection; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt) |
| 38. Settings | Actions | Choose dark app theme | ☐ | ✅ | iOS: no app override; Android: Dark selection; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt) |
| 38. Settings | Actions | Toggle wallpaper-based app colours | ☐ | ✅ | iOS: no wallpaper palette; Android: dynamic colours, API 31+; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/MainActivity.kt) |
| 39. Data & Sync | Shows | Live-edition data | ✅ | ✅ | Android: SourceDetails dialog; no profile-sync screen; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt); Android: SourceDetails from root title / source notice |
| 39. Data & Sync | Shows | Artist / event / stage counts | ✅ | ☐ | Android: Data-status dialog has no program counts |
| 39. Data & Sync | Shows | Last program download | ✅ | ◐ | Android: Timestamp shown for remote source only, not cache |
| 39. Data & Sync | Shows | Download / backup / failure status | ✅ | ✅ | — |
| 39. Data & Sync | Shows | Sync-account status | ✅ | ☐ | iOS: iCloud account; Android: Local profiles only; no cloud sync |
| 39. Data & Sync | Shows | Profile sync status | ✅ | ☐ | Android: Local profiles only; no cloud sync |
| 39. Data & Sync | Shows | Last successful profile refresh | ✅ | ☐ | Android: Local profiles only; no cloud sync |
| 39. Data & Sync | Actions | Check festival-data updates | ✅ | ✅ | — |
| 39. Data & Sync | Actions | Refresh cloud profile | ✅ | ☐ | iOS: iCloud; Android: Local profiles only; no cloud sync |
| 39. Data & Sync | Navigation | Back → More | ✅ | ✅ | Android: Dismiss status dialog opened from More |
| 39. Data & Sync | Navigation | Section title → data status | ☐ | ✅ | iOS: More entry only; Android: clickable root-page title; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 40. In-app web content | Shows | Artist website | ✅ | ◐ | iOS: Safari / embedded page; Android: External ACTION_VIEW handlers only; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt); Android: ACTION_VIEW external app/browser; no in-app web surface |
| 40. In-app web content | Shows | Festival information page | ✅ | ◐ | Android: ACTION_VIEW external app/browser; no in-app web surface |
| 40. In-app web content | Shows | Editorial link destination | ✅ | ◐ | Android: ACTION_VIEW external app/browser; no in-app web surface |
| 40. In-app web content | Shows | Web-content presentation | ✅ | ◐ | iOS: Safari / embedded page; Android: ACTION_VIEW external app/browser; no in-app web surface |
| 40. In-app web content | Actions | Read website | ✅ | ◐ | Android: ACTION_VIEW external app/browser; no in-app web surface |
| 40. In-app web content | Actions | Use website controls | ✅ | ◐ | Android: ACTION_VIEW external app/browser; no in-app web surface |
| 40. In-app web content | Actions | Use browser controls | ✅ | ◐ | iOS: Safari controls; Android: ACTION_VIEW external app/browser; no in-app web surface |
| 40. In-app web content | Navigation | Website links → destinations | ✅ | ◐ | Android: ACTION_VIEW external app/browser; no in-app web surface |
| 40. In-app web content | Navigation | Close browser → source screen | ✅ | ◐ | iOS: dismiss Safari; Android: ACTION_VIEW external app/browser; no in-app web surface |
| 40. In-app web content | Navigation | Back → source screen | ✅ | ◐ | Android: ACTION_VIEW external app/browser; no in-app web surface |
| 40. In-app web content | Navigation | Social / music → installed app | ✅ | ✅ | Android: ACTION_VIEW resolves installed handler |
| 41. News notification prompt | Shows | Notification explanation | ✅ | ✅ | iOS: pre-permission sheet; Android: Settings entry only; no separate pre-prompt; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt); Android: Settings shows background-notification explanation |
| 41. News notification prompt | Shows | Activate / decide-later options | ✅ | ◐ | Android: Settings toggle only; no pre-prompt |
| 41. News notification prompt | Actions | Activate notifications | ✅ | ✅ | Android: Settings toggle requests permission when needed |
| 41. News notification prompt | Actions | Defer decision | ✅ | ☐ | Android: No separate notification pre-prompt |
| 41. News notification prompt | Actions | Dismiss prompt | ✅ | ☐ | Android: No separate notification pre-prompt |
| 41. News notification prompt | Navigation | Request notification permission | ✅ | ✅ | iOS: system prompt; Android: POST_NOTIFICATIONS request from Settings |
| 41. News notification prompt | Navigation | Defer / dismiss → current section | ✅ | ☐ | iOS: close prompt sheet; Android: No separate notification pre-prompt |
| 41. News notification prompt | Navigation | Later access through Settings | ✅ | ✅ | Android: Notification toggle + system-settings link |
| 42. Festival-data loading / unavailable state | Shows | Loading indicator | ✅ | ✅ | Android: Spinner / generic failure + retry; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt) |
| 42. Festival-data loading / unavailable state | Shows | Loading explanation | ✅ | ☐ | Android: Spinner only before content; no loading description |
| 42. Festival-data loading / unavailable state | Shows | Connection failure | ✅ | ☐ | Android: Generic load failure; no cause-specific user message |
| 42. Festival-data loading / unavailable state | Shows | Server failure | ✅ | ☐ | Android: Generic load failure; no cause-specific user message |
| 42. Festival-data loading / unavailable state | Shows | API failure | ✅ | ☐ | Android: Generic load failure; no cause-specific user message |
| 42. Festival-data loading / unavailable state | Shows | Local-file failure | ✅ | ☐ | Android: Generic load failure; no cause-specific user message |
| 42. Festival-data loading / unavailable state | Actions | Retry loading | ✅ | ✅ | — |
| 42. Festival-data loading / unavailable state | Actions | Open website (server failures) | ✅ | ☐ | Android: No website action in startup-failure UI |
| 42. Festival-data loading / unavailable state | Actions | Choose another edition through Settings | ✅ | ☐ | Android: No Settings route before content loads |
| 42. Festival-data loading / unavailable state | Navigation | Successful loading → main navigation | ✅ | ✅ | iOS: tab interface |
| 42. Festival-data loading / unavailable state | Navigation | Open Settings | ✅ | ☐ | iOS: sheet; Android: No Settings route before content loads |
| 42. Festival-data loading / unavailable state | Navigation | Website → external destination | ✅ | ☐ | Android: No website action in startup-failure UI |
| App | Shared behaviour | Open contextual event information | ✅ | ◐ | iOS: long press + preview; Android: Timeline action menu only; no rich event preview |
| App | Shared behaviour | Preview: artist image | ✅ | ☐ | Android: No event-preview surface |
| App | Shared behaviour | Preview: time and stage | ✅ | ☐ | Android: No event-preview surface |
| App | Shared behaviour | Preview: personal rating | ✅ | ☐ | Android: No event-preview surface |
| App | Shared behaviour | Preview: private note | ✅ | ☐ | Android: No event-preview surface |
| App | Shared behaviour | Preview: optional summary | ✅ | ☐ | Android: No event-preview surface |
| App | Shared behaviour | Preview: friend attendance | ✅ | ☐ | Android: No event-preview surface |
| App | Shared behaviour | Saving: edition-dependent | ✅ | ✅ | — |
| App | Shared behaviour | Protect against accidental removal | ✅ | ☐ | iOS: confirmation; Android: Immediate bookmark toggle; no confirmation or Undo |
| App | Shared behaviour | Artist editing: metadata-dependent | ✅ | ✅ | — |
| App | Shared behaviour | Notes: private, own-device sync | ✅ | ◐ | Android: Private local notes; no cross-device sync |
| App | Shared behaviour | Friend sharing: events and ratings | ✅ | ☐ | Android: No friend sharing |
| App | Shared behaviour | Accessible schedule presentation | ✅ | ✅ | iOS: list at accessibility sizes; Android: List forced at fontScale ≥ 1.3 |
| App | Shared behaviour | Timeline details: zoom-dependent | ✅ | ✅ | Android: Cell size gates time, country, summary, indicators |
| App | Shared behaviour | Avoid duplicate map content | ✅ | ✅ | iOS: hidden map-sheet preview; Android: Map preview hidden inside place panel |
| App | Shared behaviour | Nearby-stage visibility | ✅ | ✅ | iOS: hidden in map sheet; Android: Nearby places remain visible in map panel |
| App | Shared behaviour | Editorial details: festival event routes | ✅ | ◐ | Android: Event routes open artist; editorial fields inline |
| App | Shared behaviour | Schedule / stage rows → artist details | ✅ | ✅ | — |
| App | Shared behaviour | Unread news entry point | ✅ | ✅ | iOS: tab accessory, iOS 26+; Android: Unread-count badge on News navigation item |
| App | Shared behaviour | Read controls: Rudolstadt news only | ✅ | ✅ | — |
| App | Shared behaviour | Cache-management availability | ✅ | ☐ | iOS: hidden controls; Android: No cache-management controls |
| App | Shared behaviour | Sharing / purchases / permissions: system UI | ✅ | ◐ | Android: System sharing/permissions; no purchases |
| App | Shared behaviour | Incoming artist links → matching edition | ✅ | ✅ | Android: Manifest VIEW link → edition switch → artist route |
| App | Shared behaviour | Incoming artist links → artist details | ✅ | ✅ | Android: ArtistPublicLink parsing and availability check |
| App | Shared behaviour | News notifications → news destination | ✅ | ✅ | Android: WorkManager notification PendingIntent → news/{id} |
| 43. Genre artist list | Shows | Genre title | ☐ | ✅ | iOS: no dedicated genre page; Android: GenreScreen; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 43. Genre artist list | Shows | Matching genre artists | ☐ | ✅ | iOS: global filter only; Android: independent list; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 43. Genre artist list | Actions | Browse genre without changing catalog filters | ☐ | ✅ | iOS: no dedicated route; Android: local matching query; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 43. Genre artist list | Actions | Rate directly from genre list | ☐ | ✅ | iOS: no genre page; Android: ArtistRow rating action; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 43. Genre artist list | Navigation | Artist → artist details | ☐ | ✅ | iOS: no genre page; Android: artist route; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |
| 43. Genre artist list | Navigation | Back → artist details | ☐ | ✅ | iOS: no genre page; Android: normal back stack; [Android source](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt) |

## Source references

- [Tab navigation](../iosApp/Shared/App/RootTabView.swift)
- [Detail routes](../iosApp/Shared/App/Navigation/AppNavigationRoute.swift)
- [Screen implementations](../iosApp/Shared/Screens)
- [Festival registration](../iosApp/Shared/Data/FestivalRegistry.swift)
- [Loading / failure states](../iosApp/Shared/App/FestivalDataGate.swift)

## Design references

- [Material navigation bars](https://m3.material.io/components/navigation-bar/guidelines)
- [Material bottom sheets](https://m3.material.io/components/bottom-sheets/guidelines)
- [Material menus](https://m3.material.io/components/menus/guidelines)
- [Material dialogs](https://m3.material.io/components/dialogs/guidelines)
- [Material toolbars](https://m3.material.io/components/toolbars/guidelines)
- [Android snackbars and Undo](https://developer.android.com/develop/ui/compose/components/snackbar)
- [Android navigation principles](https://developer.android.com/guide/navigation/principles)
- [Android adaptive navigation](https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-and-nav-patterns)
- [Android web-content options](https://developer.android.com/develop/ui/views/layout/webapps)

## Android source references

- [Composition, routes, rows, intents](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppUI.kt)
- [Activity, theme, foreground refresh](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/MainActivity.kt)
- [Artist catalog, country/genre/detail pages](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Artists.kt)
- [Ratings and note editor](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/ArtistActions.kt)
- [Programme, filters, category/editorial content](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Schedule.kt)
- [Timeline, zoom gestures, quick actions](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Timeline.kt)
- [Maps, places, plan, globe entry](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Maps.kt)
- [Globe rendering and reset](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Globe.kt)
- [Image states and full-screen viewer](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Design.kt)
- [News list and article details](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/News.kt)
- [Background news delivery](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/NewsWorker.kt)
- [Music preview playback](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/MusicPreview.kt)
- [Settings, travel information, About, licenses](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/Settings.kt)
- [State, local changes, loading, recommendations](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/AppModel.kt)
- [Edition catalogs and capabilities](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/data/FestivalContent.kt)
- [Program/news fetching and caches](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/data/FestivalRepository.kt)
- [Local preferences and profiles](../androidApp/src/main/kotlin/de/leongeorgi/rudolstadt/android/data/LocalSettings.kt)
- [Permissions and incoming links](../androidApp/src/main/AndroidManifest.xml)

## iOS comparison references

- [Settings and appearance](../iosApp/Shared/Screens/More/SettingsView.swift)
- [Map controls and categories](../iosApp/Shared/Screens/Map/MapOverview.swift)
- [Artist catalog navigation](../iosApp/Shared/Screens/Artist/Overview/ArtistBrowseView.swift)
- [Artist catalog rating display](../iosApp/Shared/Screens/Artist/Overview/ArtistCell.swift)
- [Country-list controls](../iosApp/Shared/Screens/Artist/Overview/ArtistCountryListRouteView.swift)
- [Globe controls and accessibility](../iosApp/Shared/Screens/Artist/Overview/ArtistWorldMapView.swift)
- [Artist details and event highlighting](../iosApp/Shared/Screens/Artist/Detail/ArtistDetailView.swift)
- [Artist description](../iosApp/Shared/Screens/Artist/Detail/ArtistDescriptionBlock.swift)
- [Timeline controls](../iosApp/Shared/Screens/Schedule/ScheduleTimelineContentView.swift)
- [Schedule list rows](../iosApp/Shared/Screens/Schedule/ScheduleListView.swift)
- [Event context-menu actions](../iosApp/Shared/SharedUI/EventActions/EventContextMenu.swift)
- [About links](../iosApp/Shared/Screens/More/AboutView.swift)
