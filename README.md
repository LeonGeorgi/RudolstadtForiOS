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
