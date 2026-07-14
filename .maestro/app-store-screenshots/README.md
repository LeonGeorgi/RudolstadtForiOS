# App Store screenshot flows

Each numbered YAML file captures one App Store screenshot and begins with the shared deterministic relaunch flow. The runner captures the six primary screenshots in light mode and the additional schedule screenshot in dark mode.

## Run

Use a dedicated booted iOS 26 iPhone or iPad simulator. The runner builds with normal simulator signing, installs the app, fixes the status bar, forces portrait orientation, and captures German and English screenshots in light and dark mode by default:

```sh
DEVICE_ID=<simulator-udid> scripts/capture-app-store-screenshots.sh
```

Optional environment variables:

- `LOCALES="de en"`
- `APPEARANCES="light dark"` (light captures screenshots 01–06; dark captures screenshot 07)
- `OUTPUT_ROOT=/path/to/output`
- `CAPTURE_ID=custom-name` to use a stable name instead of a timestamped capture set
- `DERIVED_DATA_PATH=/tmp/custom-derived-data`
- `PREBUILT_APP_PATH=/path/to/Rudolstadt.app` to skip the build

Generated PNGs are stored below `AppStoreScreenshots/<locale>/<appearance>/<device>/<capture-id>/` and are ignored by Git. A new capture ID prevents screenshots from older selections remaining in the current set.

Run the command once for each local device. For the required iPad App Store slot, use a 13-inch iPad Pro or Air simulator (2064 × 2752 pixels) or a compatible 12.9-inch iPad Pro simulator (2048 × 2732 pixels).

## GitHub Actions

Run the **App Store Screenshots** workflow manually from the Actions tab. It builds the app once, then captures German and English sets for both iPhone and a 13-inch/12.9-inch iPad. Every locale and device family receives a separate artifact containing the light set and the dark schedule screenshot.

The app's `-screenshotMode` launch argument loads the bundled festival and news backups, disables network refreshes and CloudKit, and resets screenshot-relevant preferences. It also seeds a presentation-ready local profile and friend recommendations. Artist photography and Apple map tiles are still rendered by their normal production components, so allow those views to settle before capture.
