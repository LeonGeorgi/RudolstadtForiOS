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
Als neuer manueller Workflow kann er über GitHub erst nach dem Merge in `master`
gestartet werden. Die vorhandenen Screenshot-Workflows erlauben bereits auf dem
PR-Branch den nativen Telefon-/Tablet-Test.

Die Messung umfasst Installation, Geräteeinstellungen, Treiberstart, Navigation,
Aufnahmen und Export. App-Build und Emulatorstart sind ausgeschlossen; die Geräte
müssen vorher gestartet sein. Der gemeinsame erste App-/Runtime-Start wird vor beiden
Werkzeugen ausgeführt und separat als `common_preparation_seconds` berichtet. So trägt
nicht allein das erste Werkzeug den Kaltstart. Es werden keine Capture-Läufe verworfen. Vorhandene
gezielte Maestro-Treiber-Retries bleiben Teil der gemessenen Zeit und in den Logs
sichtbar. XCTest/UI Automator wiederholen fehlgeschlagene Capture-Läufe nicht.
Der Report prüft vollständige Dateisätze, PNG-Header, Auflösungen und Prüfsummen;
die HTML-Galerie dient zur visuellen Prüfung. Unterschiedliche Scroll-Gesten,
Kartenkacheln und nachgeladene Bilder verhindern einen sinnvollen pauschalen
Pixelgleichheits-Test. Zwei erfolgreiche Runden belegen keine langfristige Stabilität.

## Lokale Messung vom 1. November 2026

Android: Pixel-7a-Profil, API 36 / Google APIs ARM64, 1080 × 2400 Pixel,
Maestro 2.12.0 gegen UI Automator 2.4.0. Zwei vollständige Runden mit identischem APK
(SHA-256 `3dd5596bbc2f05c15efd2726667e6c8fdf941e18b121e7404697a61d7e99f343`).
Die App war hier bereits durch den vorausgehenden Funktionstest initialisiert.

| Werkzeug | Runde 1 | Runde 2 | Median | Vollständige Sätze |
| --- | ---: | ---: | ---: | ---: |
| Maestro | 161,24 s | 120,24 s | 140,74 s | 2/2, je 16 PNGs |
| UI Automator | 51,08 s | 58,83 s | 54,95 s | 2/2, je 16 PNGs |

Das entspricht rund 61 % weniger Zeit für UI Automator. Alle 64 PNGs wurden zusätzlich
mit Pillow dekodiert/geprüft. In Runde 1 sind 13/16 Paare pixelgleich; die übrigen drei
Paare sind Kartenansichten. Die visuelle Gegenüberstellung zeigt bei beiden Werkzeugen
geladene Karten und dieselben Hauptansichten in beiden Darstellungen.
Auf diesem Entwicklungsrechner lief parallel eine iOS-Funktionsprüfung. Die Zahlen
geben eine praktische Größenordnung an, keine isolierte Leistungs- oder CI-Kostenmessung.
Geräte, Karten-/Bild-Caches und Runnerlast beeinflussen die Dauer.

iOS: eigener iPhone-17-Simulator mit iOS 27.0, Xcode 27.1, 1206 × 2622 Pixel.
Auf diesem Rechner war kein iOS-26-Runtime installiert; die CI-Matrix prüft separat
iOS 26. Eine vollständige Runde mit beiden Sprachen und demselben signierten App-Build
(SHA-256 der App-Binary `212d9a7968f72a7e27955566008f2830b07753a605740020541613e556bd55c9`).

| Werkzeug | Zeit einschließlich Setup/Export | Vollständiger Satz |
| --- | ---: | ---: |
| Maestro 2.12.0 | 203,06 s | 14/14 PNGs |
| XCTest | 193,80 s | 14/14 PNGs |

Der gemeinsame Vorlauf dauerte 1,44 s und ist separat erfasst. Hier beträgt der
gemessene Vorteil rund 5 %. Maestro lief zuerst; beide Werkzeuge
profitierten bereits von Karten-/Bild-Caches aus der Funktionsprüfung. Mit nur einer
Runde lässt sich der kleine Unterschied nicht sicher von Reihenfolge und Last trennen.
Die Aufnahmen enthalten dieselben sieben Ansichten. Scrollpositionen und rotierende
News-Texte können abweichen; es handelt sich nicht um Pixel-Baselines.
Ein früherer warmer Lauf lag bei 218,97 s / 195,15 s. Ein Kontrolllauf nach erneutem
Simulatorstart lag bei 281,68 s / 197,86 s; dort trug das zuerst gestartete Maestro
noch den gemeinsamen ersten App-Start. Das begründet die separate Initialisierungsphase
des endgültigen Messverfahrens und zeigt, warum aus einzelnen Läufen keine allgemeine
iOS-Geschwindigkeitsgarantie abgeleitet werden kann.

Für Android ist UI Automator damit ein aussichtsreicher Standard: gleicher Bildsatz
bei deutlich weniger Laufzeit und ohne zusätzlichen Maestro-Treiber. XCTest ist ein
funktionsfähiger iOS-Ersatz mit direkten Assertions und nativen Diagnoseberichten;
der kleinere gemessene Zeitvorteil rechtfertigt allein noch keine Stabilitätsaussage.
Die Werkzeugauswahl bleibt bis zur Auswertung der CI-Matrix manuell möglich,
Maestro bleibt in diesem PR die Voreinstellung.

## CI-Verifikation

- [UI Automator: Pixel 7 Pro und Pixel Tablet](https://github.com/LeonGeorgi/RudolstadtForiOS/actions/runs/41286115013):
  beide erfolgreich, je 16 Aufnahmen. Der bisherige SwiftShader-Grafikmodus ließ
  Kartensymbole und Beschriftungen aus; mit `-gpu swangle` sind sie in den geprüften
  Bildern sichtbar. Die App-Bibliotheken wurden dafür nicht geändert.
- [XCTest: iPhone 17 Pro und iPad Pro 13-inch, iOS 26](https://github.com/LeonGeorgi/RudolstadtForiOS/actions/runs/41287113366):
  beide erfolgreich, je 14 Aufnahmen. Der generische Build verwendet ARM64 passend
  zum Kotlin-Simulatortarget. Beide iOS-Werkzeuge starten die Seed-App vor ihrer
  Automation; XCTest erlaubt für einen vollständigen Sprachsatz bis zu zehn Minuten
  auf langsamen CI-Runnern. Es gibt keine Testwiederholung als Ersatz für fehlschlagende
  Assertions. Die früheren iOS-Kaltstartfehler bleiben in den Diagnose-Läufen nachvollziehbar.

Die Publisher laufen auf einem PR-Branch nicht. Das Android-Galerieformat wurde mit
den nativen Telefon-/Tablet-Dateien geprüft; die iOS-Anhänge werden in das bestehende
`locale/device/capture-id`-Format exportiert. Veröffentlichte README-Bilder werden
erst durch einen vollständigen erfolgreichen Lauf auf `master` ersetzt.

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
