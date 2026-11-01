# Screenshot-Automation

Die Screenshots entstehen durch normale sichtbare Navigation mit XCTest unter iOS
und UI Automator 2.4 unter Android. Es gibt pro Plattform genau einen Capture-Pfad.

| Plattform | Test | Aufnahmen pro Gerät |
| --- | --- | --- |
| iOS | `Native Screenshots`, bestehendes UI-Test-Target | 7 Ansichten × Deutsch/Englisch = 14 |
| Android | Modul `androidScreenshotTests` | 4 Ansichten × Deutsch/Englisch × Hell/Dunkel = 16 |

## GitHub Actions und README

**App Store Screenshots** läuft manuell und nimmt auf einem iPhone sowie einem
13-Zoll-iPad jeweils beide Sprachen auf. Der ARM64-Build enthält App und XCTest-Bundle
und wird von beiden Geräten verwendet. XCTest startet nach einem App-Vorlauf, damit
frische CI-Simulatoren ihre Laufzeit-Caches initialisieren können. Pro Sprachsatz
gilt auf langsamen Runnern ein Zeitlimit von zehn Minuten.

**Android Screenshots** läuft manuell sowie bei Android-relevanten Pull Requests und
Änderungen auf `master`. App und UI-Automator-APK werden einmal gebaut und auf einem
Pixel 7 Pro sowie Pixel Tablet verwendet. Der CI-Emulator nutzt `-gpu swangle`, damit
auch Kartensymbole und Beschriftungen zuverlässig dargestellt werden.

Ein fehlgeschlagener Test oder ein unvollständiger Bildsatz beendet die Aufnahme mit
Fehler. Berichte, Logs und Fehlerbilder werden als Diagnosen hochgeladen; iOS behält
zusätzlich das `xcresult` mit seinen Anhängen. Es gibt keine automatischen Test-Retries.

Erst ein vollständig erfolgreicher Lauf auf `master` veröffentlicht die Bilder:
iOS über die bestehende GitHub-Pages-Galerie, Android über den Branch `screenshots`.
Beide Publisher erstellen kleine Vorschaubilder und behalten die stabilen Bildadressen
der Haupt-README bei. PR-Läufe ersetzen keine veröffentlichten Bilder.

## Lokal: Android

Voraussetzungen: JDK 17, Android SDK, Python 3.10 oder neuer und ein dedizierter,
gestarteter Emulator ab API 33. CI verwendet API 36. Physische Geräte werden vom
Capture-Skript abgelehnt. Der Runner installiert beide APKs und ändert App-Sprache,
Systemdarstellung und Statusleiste; er löscht keine App-Daten. Für reproduzierbare
Aufnahmen einen frischen Emulator mit der Theme-Einstellung „System“ verwenden.

```sh
./gradlew :androidApp:assembleDebug :androidScreenshotTests:assembleDebug
ANDROID_SERIAL=emulator-5554 bash scripts/android/capture-screenshots.sh
```

Optional: `PREBUILT_APK_PATH`, `NATIVE_TEST_APK_PATH`, `LOCALES='de en'`, `OUTPUT_ROOT`
und `DIAGNOSTICS_ROOT`. Standardausgabe:
`artifacts/screenshots/android/<locale>/<light|dark>/`.
Das Testmodul ist selbst instrumentiert, damit App-Neustarts den Testprozess nicht
beenden. Das `city-map-ready`-Signal wartet auf das tatsächliche Rendern der Karte.
Programm, Bilder und Karten verwenden das normale Ladeverhalten einschließlich
gebündeltem Fallback und vorhandenen Caches; Netzwerkzugriff kann erforderlich sein.

## Lokal: iOS

Voraussetzungen: Xcode, JDK 17 für den Build, Python 3.10 oder neuer und ein dedizierter
Simulator. Normale Simulator-Signierung einschließlich CloudKit-Entitlements bleibt
aktiv. Immer eigenes DerivedData verwenden.

```sh
DEVICE_ID=<simulator-udid> \
DERIVED_DATA_PATH=/tmp/RudolstadtScreenshots \
  bash scripts/ios/capture-app-store-screenshots.sh
```

Mit `XCTEST_RUN_FILE=/path/to/Native\ Screenshots_....xctestrun` wird der Build
übersprungen. `PREBUILT_APP_PATH` kann die dazugehörige App explizit angeben;
standardmäßig wird sie relativ zur Testdatei unter `Debug-iphonesimulator` gefunden.
CI verwendet auf beiden Geräten denselben vorgebauten App-/Test-Satz.

Optional: `LOCALES='de en'`, `OUTPUT_ROOT`, `DIAGNOSTICS_ROOT` und `CAPTURE_ID`.
Standardausgabe: `artifacts/screenshots/app-store/<locale>/<device>/<capture-id>/`.
Neue Capture-IDs verhindern, dass ältere Dateien einen fehlgeschlagenen Lauf verdecken.
`xcresulttool` exportiert benannte Screenshot-Anhänge; erst ein vollständiger Satz
wird in das Galerieformat übernommen. Exportprüfung:

```sh
python3 -m unittest discover -s scripts/ios -p '*_test.py'
```

Der bestehende `-screenshotMode` lädt gebündelte Festival-/News-Daten, deaktiviert
Netzwerk-Refresh und CloudKit, setzt Screenshot-Einstellungen zurück und erstellt
Demo-Profile. Er navigiert nicht selbst zu den Ansichten. Künstlerbilder und
Apple-Karten werden weiterhin durch die Produktionskomponenten geladen.

## Grundlage der Umstellung

Der lokale Vergleich vom 1. November 2026 verwendete pro Plattform denselben App-Build
und dasselbe Telefon. Installation, Einrichtung, Navigation und Export waren enthalten;
Build, Boot und gemeinsame erste App-Initialisierung waren ausgenommen.

| Plattform | Vorher mit Maestro | Nativ | Stichprobe |
| --- | ---: | ---: | --- |
| Android, API 36 ARM64 | 140,74 s | 54,95 s | Median aus 2 Runden, je 16 PNGs |
| iOS 27 / Xcode 27.1 | 203,06 s | 193,80 s | 1 Runde, je 14 PNGs |

Android zeigte rund 61 % weniger Laufzeit, iOS einen kleinen Unterschied von rund 5 %.
Warme Bild-/Karten-Caches, Runnerlast und die kleinen Stichproben begrenzen die Aussage
über CI-Laufzeiten und langfristige Stabilität. Android lief parallel zu einer
iOS-Funktionsprüfung. Die ursprünglichen Messwerkzeuge bleiben in der Git-History
erhalten. Die native Geräte-Matrix wurde zusätzlich mit API 36 x86_64 und iOS 26
erfolgreich geprüft; ursprüngliche Referenzläufe:
[Android](https://github.com/LeonGeorgi/RudolstadtForiOS/actions/runs/41286115013),
[iOS](https://github.com/LeonGeorgi/RudolstadtForiOS/actions/runs/41287113366).
