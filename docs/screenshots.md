# Screenshot-Automation

Die Screenshots entstehen durch normale sichtbare Navigation mit XCTest unter iOS
und UI Automator 2.4 unter Android. Es gibt pro Plattform genau einen Capture-Pfad.

Der Abgleich mit den editierbaren Entwürfen folgt zusätzlich den
[Sketch-Regeln](#sketch-abgleich-und-visuelle-abnahme). Die Capture-Pipeline und
deren Referenzen bleiben davon unabhängig.

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

## Manuelle iOS-Regressionstests

Die drei bisherigen Regressionen liegen als `NavigationRegressionTests` im selben
UI-Test-Target: Festivalwechsel mit benutzbaren Tabs, Freundesbewertungen mit einem
oder mehreren Freunden und Navigation zwischen Karten-Sheets, Künstlern und
klassischen Ortsdetails. Sie werden unabhängig von der Screenshot-Aufnahme gestartet:

```sh
xcodebuild test \
  -project iosApp/RudolstadtForiOS.xcodeproj \
  -scheme 'Native Screenshots' \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' \
  -derivedDataPath /tmp/RudolstadtUIRegressions \
  -parallel-testing-enabled NO \
  -only-testing:'Tests iOS/NavigationRegressionTests' \
  -resultBundlePath /tmp/RudolstadtNavigationRegressions.xcresult
```

Auch hier einen dedizierten Simulator und einen neuen Ergebnispfad verwenden.
Der Festivaltest nutzt normalen App-Zustand, wechselt durch aktuelle und archivierte
Ausgaben und stellt zuletzt Rudolstadt 2026 ein; Profile und gespeicherte Daten werden
nicht gelöscht. Die beiden anderen Tests verwenden die isolierten Demo-Profile des
Screenshot-Modus. Vier benannte Screenshot-Anhänge bleiben zur Kontrolle im `xcresult`.
Die Capture-Pipeline wählt ausschließlich `NativeScreenshotTests` aus und führt diese
Regressionen daher nicht zusätzlich bei jeder Bildaufnahme aus.

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

## Sketch-Abgleich und visuelle Abnahme

Diese Regeln gelten für neue Seiten und Änderungen an bestehenden Screens.
Grundlage ist der iOS-Abgleich vom 3./4. November 2026. Der vorhandene
[Vergleichsbericht](../design/audit-2026-11-03/index.html) enthält Quellen,
Kanalbilder und die Grenzen der tatsächlich geprüften Zustände.
Der [Stilkatalog vom 4. November](../design/audit-2026-11-03/shared-styles-2026-11-04.json)
führt die gemeinsamen Schriftrollen, Farbvariablen und Sketch-IDs auf.
Für neue Seiten passende aktuelle Rollen wiederverwenden; im Dokument erhaltene
ältere Konzeptstile nicht allein anhand ihres Namens als aktuelle Vorgabe ansehen.

### Gemeinsame Regeln vor einzelnen Seiten korrigieren

1. Wiederkehrende Abweichungen zuerst auf gemeinsame Textstile, Farbvariablen und
   Symbol Sources zurückführen. Nachrichtenleiste, Event-Zeilen, Profilzeilen,
   Bewertungszeilen und Datums-Badges an ihrer Quelle korrigieren. Instanzen live
   verknüpft lassen; sinnvolle Inhalts- und Zustands-Overrides erhalten.
   Vor der Feinabstimmung prüfen, ob alte und neue Komponenten gleichzeitig
   sichtbar sind: eine doppelte Leiste kann versetzte Schrift und zusätzliche
   Materialflächen erzeugen. Systemelemente entsprechend dem tatsächlichen
   Referenzzustand darstellen, beispielsweise einen automatisch ausgeblendeten
   Home-Indikator. Solche Unterschiede im Entwurf beheben und nicht zusätzlich
   aus dem Differenzbild maskieren.
2. Typografie vollständig festlegen: Schriftfamilie, Größe, Gewicht, variable
   Achsen, Laufweite, Zeilenhöhe, Ausrichtung und Farbe. Für den geprüften iOS-Stand
   passt die variable **SF Pro**. Statische SF Pro Text/Display sind kein
   gleichwertiger Ersatz. Die geprüften Achsen sind Width 100, Optical Size auf
   die Punktgröße begrenzt auf 17–28 sowie Weight 400/510/590/700 für
   Regular/Medium/Semibold/Bold. Die Werte anhand des gerenderten Ergebnisses
   prüfen; ein SwiftUI-/UIKit-Stilname allein bestimmt das Ergebnis nicht.
   OpenType-Merkmale ebenfalls übernehmen: `.monospacedDigit()` entspricht
   in Sketch **Text → OpenType Features → Number Spacing → Monospaced Numbers**.
   Dabei die SF-Pro-Schrift behalten; SF Mono wäre eine andere Schriftform.
   Das Merkmal im gemeinsamen Zeitstil speichern und seine Instanzen erneut
   vergleichen. Die öffentliche Sketch-API zeigt nicht alle Schriftmerkmale in
   `style.toJSON()` an; gerenderte Textfragmente und Exportbilder mitprüfen.
   Achsen nach dem Setzen frisch vom Textlayer lesen und den Export kontrollieren;
   ein fehlerfrei ausgeführter API-Aufruf belegt noch keine wirksame Änderung.
3. Textrollen unterscheiden: einzeilige Labels, mehrzeiliger Fließtext,
   Überschriften und Inline-Anhänge haben unterschiedliche Zeilenmetriken.
   Rahmen, erste Grundlinie, weitere Grundlinien und Umbrüche separat prüfen.
   Der geprüfte Nachrichten-Fließtext nutzt 17 pt und 22 pt Zeilenabstand;
   diese Zeilenhöhe nicht pauschal auf alle 17-pt-Labels übertragen.
   Zeilenlimits, Mindestskalierung und Abschneiden langer Titel gehören ebenfalls
   zum Komponentenverhalten und benötigen repräsentative lange Testtexte.
4. Native semantische Farben einschließlich Alpha, Hintergrund und Komponenten-
   kontext übernehmen. UIKit-Label-Secondary ist im geprüften hellen Zustand
   `#3c3c4399`, im dunklen Zustand `#ebebf599`. Reiner SwiftUI-Secondary-Text
   erscheint in den geprüften hellen Profil- und Hilfetexten dagegen als Schwarz
   mit 50 % Alpha (`#00000080`). Ein gemeinsamer Secondary-Stil für beide Fälle
   wäre falsch. Bei Placeholdern und Material-Hintergründen ebenfalls den
   tatsächlich aufgelösten Farbwert prüfen.
   Transparente Timeline-Karten nicht durch ihre auf Weiß verrechnete Vollfarbe
   ersetzen: sonst fehlen die durchscheinenden Rasterlinien. Metadaten und Tags
   haben dort eigene Alpha-Werte und verwenden keinen allgemeinen Secondary-Stil.
5. Erst nach der Komponentenprüfung verbleibende Seitenpositionen korrigieren.
   Gemessene Bruchteile von Punkten erhalten: bei 3× entspricht ein Bildpixel
   einem Drittel Punkt. Ein Versatz ist kein allgemeiner Korrekturwert für
   andere Schriften, Zeilenhöhen, Geräte oder Betriebssystemversionen.

Text und UI-Struktur bleiben editierbar. Ganze Screens oder Textblöcke nicht durch
Simulator-Bitmaps ersetzen, um Differenzbilder schwarz erscheinen zu lassen.
Native Symbol-/Bildassets dürfen als solche verwendet werden; ihre Herkunft muss
nachvollziehbar bleiben. Frühere Konzepte und andere Plattformen nicht durch
globale Änderungen an unpassenden gemeinsamen Stilen verändern.

### Entwürfe und Kartenassets

„Noch nicht implementiert“, „nicht im Pixelvergleich“ und „ältere Variante“
bedeuten nicht automatisch „verworfen“. Offene Ideen und geplante Arbeiten
behalten, insbesondere die Varianten in **Mein Plan**. Nur Alternativen entfernen,
bei denen die Designentscheidung feststeht; bei Unklarheit die konkreten
Entwurfsnamen zur Auswahl nennen. Vor dem Entfernen eine vollständige Sicherung
anlegen und die Auswahl nachvollziehbar festhalten.
Vollständige lokale Sicherungen liegen unter `design/recovery/` und werden nicht
mit versioniert. Die Arbeitsdatei, Kartenassets und Prüfberichte gehören ins Repo.

Die drei aktuellen Weltkarten verwenden ausschließlich für die Kartenfläche
PNG-Assets bei 3× aus den datierten Simulatorreferenzen. Navigation, Texte,
Attribution und App-Leisten bleiben eigene editierbare Ebenen. Quellen,
Ausschnitte und Prüfsummen stehen in [design/maps/manifest.json](../design/maps/manifest.json).
Die ausführlichen Vektoren liegen in der Sicherung außerhalb der Arbeitsdatei;
ausgeblendete Vektorkopien würden deren Ladeaufwand weiterhin erhalten.

### Reproduzierbarer Vergleich

Für jedes Bildpaar Gerät, OS-Version, Auflösung/Skalierung, Sprache,
Darstellung, Dynamic-Type-Größe, Inhalt/Testdaten und Scroll-/Zoomzustand
festhalten. Mit demselben Zustand vergleichen. Bestehende Aufnahmen als datierte
Referenzen kennzeichnen; sie belegen keinen Lauf eines späteren App-Builds.
Eine vom Nutzer autorisierte Simulatorprüfung folgt weiterhin dem Capture-Pfad
oben und verwendet keine zusätzlichen Produktions-Navigationshilfen.

Sketch ohne Beschnitt bei derselben Auflösung wie den Simulator exportieren.
Die Quellen nicht automatisch ausrichten, verschieben, skalieren oder weichzeichnen:
Dadurch würden echte Layoutfehler verschwinden. Nach jeder Komponentenänderung
mindestens eine betroffene Instanz in Sketch visuell kontrollieren und anschließend
alle betroffenen Vergleichs-Screens neu exportieren.

Die Graustufen-Kanaldifferenz nutzt `d = Grau(Simulator) - Grau(Sketch)` und
`RGB = (max(d, 0), max(-d, 0), max(d, 0))`:

- Schwarz: gleiche Helligkeit.
- Magenta: Sketch ist dunkler.
- Grün: Simulator ist dunkler.

Für die vorhandene iPhone-Referenz (402 × 874 pt @3×) sind ausschließlich die
oberen 62 pt / 186 Pixel der Systemleiste maskiert. Liquid-Glass-Materialeffekte
sind von der Beurteilung ausgenommen; Schrift und Symbole darauf bleiben sichtbar
und werden geprüft. Andere Abweichungen nicht als zusätzliche Ausnahme verstecken.
Zusätzlich das RGB-Differenzbild prüfen, da gleiche Graustufen Farbfehler verdecken.

```sh
python3 design/audit-2026-11-03/tools/channel_difference.py \
  sketch.png simulator.png channels.png --ignore-top 186
```

Nach einem Komponenten-Abgleich alle 22 aktuellen Frames anhand der IDs im
Manifest erneut unbeschnitten bei 3× exportieren. Der Bericht lässt sich mit
denselben Simulatorreferenzen reproduzierbar aktualisieren:

```sh
python3 design/audit-2026-11-03/tools/update_comparisons.py \
  --exports /path/to/after --baseline /path/to/before \
  --review-date 2026-11-04
```

Die Baseline muss vor den Änderungen exportiert sein. Das Werkzeug prüft die
Referenz-Prüfsummen und Bildgrößen und erzeugt Kanalbilder, RGB-Differenzen,
50-%-Überlagerungen und die Vorher-Kanalbilder neu.

Das Werkzeug benötigt Pillow. Quellen und Ergebnis verlustfrei speichern und
Abmessungen sowie Prüfsummen im Manifest festhalten. Vorher/Nachher-Ausschnitte
und benannte Text-/Komponentenbereiche eignen sich zum Nachweis einer Korrektur.
Ein Durchschnitt über große weiße Flächen ist keine Pixel-Passquote.
Verbleibende Abweichungen und nicht erreichbare Zustände im Bericht ausdrücklich
benennen; eine Komponentenänderung ist erst nach dem erneuten Vergleich geprüft.
