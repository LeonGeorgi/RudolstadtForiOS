# App Store screenshot flows

Each YAML file captures one independent App Store screenshot. The runner relaunches the app in deterministic screenshot mode before every flow, so a failed flow does not invalidate later screenshots.

## Run

Use a dedicated booted iOS 26 simulator. The runner builds with normal simulator signing, installs the app, fixes the status bar, and captures German and English light-mode screenshots by default:

```sh
DEVICE_ID=<simulator-udid> Scripts/capture-app-store-screenshots.sh
```

Optional environment variables:

- `LOCALES="de en"`
- `APPEARANCES="light dark"`
- `OUTPUT_ROOT=/path/to/output`
- `DERIVED_DATA_PATH=/tmp/custom-derived-data`

Generated PNGs are stored below `AppStoreScreenshots/<locale>/<appearance>/<device>/` and are ignored by Git.

The app's `-screenshotMode` launch argument loads the bundled festival and news backups, disables network refreshes and CloudKit, and resets screenshot-relevant preferences. Artist photography and Apple map tiles are still rendered by their normal production components, so allow those views to settle before capture.
