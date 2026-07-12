# App Store screenshot flows

Each numbered YAML file captures one App Store screenshot and begins with the shared deterministic relaunch flow. The runner submits all six files to one Maestro session per locale and appearance.

## Run

Use a dedicated booted iOS 26 simulator. The runner builds with normal simulator signing, installs the app, fixes the status bar, and captures German and English light-mode screenshots by default:

```sh
DEVICE_ID=<simulator-udid> scripts/capture-app-store-screenshots.sh
```

Optional environment variables:

- `LOCALES="de en"`
- `APPEARANCES="light dark"`
- `OUTPUT_ROOT=/path/to/output`
- `DERIVED_DATA_PATH=/tmp/custom-derived-data`
- `PREBUILT_APP_PATH=/path/to/Rudolstadt.app` to skip the build

Generated PNGs are stored below `AppStoreScreenshots/<locale>/<appearance>/<device>/` and are ignored by Git.

## GitHub Actions

Run the **App Store Screenshots** workflow manually from the Actions tab. It builds the app once, then runs German and English captures concurrently on separate iOS 26 runners. Each locale uses one Maestro session, uploads its own artifact, and reports phase timings in the log.

The app's `-screenshotMode` launch argument loads the bundled festival and news backups, disables network refreshes and CloudKit, and resets screenshot-relevant preferences. Artist photography and Apple map tiles are still rendered by their normal production components, so allow those views to settle before capture.
