# XCTest / UI Automator im Vergleich mit Maestro

Für beide Plattformen existiert jetzt ein nativer Screenshot-Pfad neben Maestro:

| Plattform | Nativ | Aufnahmen pro Gerät |
| --- | --- | --- |
| iOS | XCTest, bestehendes UI-Test-Target, Scheme `Native Screenshots` | 7 Ansichten × Deutsch/Englisch = 14 |
| Android | UI Automator 2.4.0, separates Modul `androidScreenshotTests` | 4 Ansichten × Deutsch/Englisch × Hell/Dunkel = 16 |

Die Tests navigieren durch die sichtbare App. Sie verwenden dieselben Ansichten,
Dateinamen und Locale-/Appearance-Kombinationen wie die bestehenden Maestro-Flows.
Unter iOS bleibt der bestehende `-screenshotMode` mit gebündelten Daten aktiv.
Android verwendet weiterhin die reguläre App und deren Daten-/Karten-Cache.
Ein gemeinsames `city-map-ready`-Signal verhindert dort Aufnahmen vor dem tatsächlichen
Rendern der Karte. Weder ein leerer Screenshot-Ordner noch ein fehlgeschlagener
Instrumentation-Lauf gilt als Erfolg.

## GitHub Actions und README

**Android Screenshots** und **App Store Screenshots** bieten beim manuellen Start
die Auswahl `engine: maestro` oder `native`. Automatische Android-Läufe und die
Voreinstellung bleiben vorerst bei Maestro. Native Aufnahmen benutzen dieselben
Galerie-Publisher: Nach einem vollständig erfolgreichen Lauf auf `master` werden
dieselben stabilen README-Bildadressen aktualisiert. Ein PR-Lauf veröffentlicht keine Bilder.

**Compare Screenshot Engines** baut eine App pro Plattform und führt beide Werkzeuge
auf demselben Telefon nacheinander aus. Standardmäßig gibt es zwei Runden in der
Reihenfolge Maestro → Nativ, dann Nativ → Maestro. Beide verwenden Maestro 2.12.0
als Vergleichsbasis; der bisherige iOS-Publisher verwendet weiterhin 2.6.1.
Der Vergleich lädt `report.json`, `summary.md`, `gallery.html`, Originalbilder und
Diagnosen hoch, auch wenn ein Werkzeug scheitert. Er veröffentlicht die Ergebnisse
nicht automatisch als README-Galerie.

Die Messung umfasst Installation, Geräteeinstellungen, Treiberstart, Navigation,
Aufnahmen und Export. App-Build und Emulatorstart sind ausgeschlossen; die Geräte
müssen vorher gestartet sein. Es gibt keinen verworfenen Aufwärmlauf. Vorhandene
gezielte Maestro-Treiber-Retries bleiben Teil der gemessenen Zeit und in den Logs
sichtbar. XCTest/UI Automator wiederholen fehlgeschlagene Capture-Läufe nicht.
Der Report prüft vollständige Dateisätze, PNG-Header, Auflösungen und Prüfsummen;
die HTML-Galerie dient zur visuellen Prüfung. Unterschiedliche Scroll-Gesten,
Kartenkacheln und nachgeladene Bilder verhindern einen sinnvollen pauschalen
Pixelgleichheits-Test. Zwei erfolgreiche Runden belegen keine langfristige Stabilität.

## Lokal: Android

Voraussetzungen: JDK 17, Android SDK/API 36, dedizierter gestarteter Emulator,
Maestro 2.12.0 für den Vergleich, Python 3.10 oder neuer. Der Controller lehnt
physische Geräte ab und verändert Sprache, Darstellung und Statusleiste nur auf
dem ausdrücklich angegebenen Emulator.

```sh
./gradlew :androidApp:assembleDebug :androidScreenshotTests:assembleDebug

ANDROID_SERIAL=emulator-5554 SCREENSHOT_ENGINE=native \
  bash scripts/android/capture-screenshots.sh

ANDROID_SERIAL=emulator-5554 \
  python3 scripts/compare_screenshot_engines.py android \
  --output artifacts/screenshots/comparison-android --rounds 2
```

Optional: `PREBUILT_APK_PATH`, `NATIVE_TEST_APK_PATH`, `LOCALES='de en'`,
`OUTPUT_ROOT`, `DIAGNOSTICS_ROOT`. Das Testmodul ist selbst instrumentiert;
ein Neustart der App für Sprache/Darstellung beendet deshalb nicht den Testprozess.

## Lokal: iOS

Voraussetzungen: Xcode, JDK 17, dedizierter gestarteter Simulator, Python 3.10 oder
neuer; Maestro 2.12.0 nur für den Vergleich. Normale Simulator-Signierung bleibt
aktiv, einschließlich der CloudKit-Entitlements. Immer eigenes DerivedData verwenden.

```sh
DEVICE_ID=<simulator-udid> \
DERIVED_DATA_PATH=/tmp/RudolstadtNativeScreenshots \
  bash scripts/ios/capture-native-screenshots.sh
```

Für den Vergleich einmal vorbauen und beide Werkzeuge mit genau diesem Build starten:

```sh
export DEVICE_ID=<simulator-udid>
export DERIVED_DATA_PATH=/tmp/RudolstadtNativeScreenshots
BUILD_ONLY=1 DIAGNOSTICS_ROOT=artifacts/native-build \
  bash scripts/ios/capture-native-screenshots.sh

export XCTEST_RUN_FILE="$(python3 -c 'import json; print(json.load(open("artifacts/native-build/build.json"))["test_run"])')"
export PREBUILT_APP_PATH="$(python3 -c 'import json; print(json.load(open("artifacts/native-build/build.json"))["app"])')"
python3 scripts/compare_screenshot_engines.py ios \
  --output artifacts/screenshots/comparison-ios --rounds 2
```

`XCTEST_RUN_FILE` überspringt den Build. Die native Ausgabe liegt unter
`<OUTPUT_ROOT>/<locale>/<device>/<capture-id>/`, genau wie bei Maestro.
`xcresulttool` exportiert benannte Screenshot-Anhänge; erst ein vollständiger Satz
wird übernommen. `LOCALES`, `CAPTURE_ID` und die Ausgabe-/Diagnosepfade sind optional.
Ausgabeordner eines Vergleichs müssen neu sein, damit keine alten Bilder einen
fehlgeschlagenen Lauf verdecken.

## Wartungsaufwand und Grenzen

| Aspekt | Maestro | XCTest / UI Automator |
| --- | --- | --- |
| Flow-Pflege | YAML, ähnliche Sprache auf beiden Plattformen | Swift und Kotlin, zwei plattformspezifische Tests |
| Treiber | zusätzlicher Maestro-Treiber, JVM/CLI | Apples UI-Test-Runner bzw. Android-Instrumentation |
| Zustandsprüfung | Accessibility-Selektoren, explizite Wartebedingungen | typisierte Abfragen und direkte Assertions, native Ergebnisberichte |
| Screenshot-Export | PNGs direkt im Flow | Android direkt; iOS zusätzlicher `xcresult`-Export |
| Gemeinsame Grenze | geänderte Navigation/Accessibility und externe Bild-/Kartendaten | dieselbe Grenze; native APIs beheben veraltete Selektoren nicht automatisch |

UI Automator 2.4 ist eine veröffentlichte stabile Version. Das selbst instrumentierte
Testmodul folgt dem offiziellen Android-Testmodul-Muster. XCTest nutzt Apples
Screenshot-Anhänge statt eines zusätzlichen Treibers.

Quellen: [UI-Automator-Releases](https://developer.android.com/jetpack/androidx/releases/test-uiautomator),
[offizielles Android-Testmodul-Beispiel](https://github.com/android/performance-samples/blob/main/MacrobenchmarkSample/macrobenchmark/build.gradle.kts),
[Apple XCUIScreenshot](https://developer.apple.com/documentation/xcuiautomation/xcuiscreenshot).
