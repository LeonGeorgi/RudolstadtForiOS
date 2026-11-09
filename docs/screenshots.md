# Screenshot-Automation

Die Screenshots entstehen durch normale sichtbare Navigation mit XCTest unter iOS
und UI Automator 2.4 unter Android. Es gibt pro Plattform genau einen Capture-Pfad.

Der vollständige [Sketch-Abgleich](#sketch-abgleich-und-visuelle-abnahme) gehört
zur gezielten Designabnahme. Die Capture-Pipeline und deren Referenzen bleiben
davon unabhängig.

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

## Android: Mein Plan separat prüfen

`PersonalPlanTests` im vorhandenen UI-Automator-Modul prüft zusätzlich die neue
Planansicht über die normale Navigation: gewählter Tag, Leerzustand,
Empfehlungsmenü, vergangene gemerkte Konzerte, Pausen, Fußwege, Konflikthinweise,
Konzertdetails und das Entfernen eines gemerkten Konzerts. Die vier regulären
Capture-Ansichten und deren CI-Aufruf bleiben unverändert.

Die App einmal auf einem dedizierten Emulator initialisieren. Der Test bricht vor
Änderungen ab, wenn er keine gültige bestehende Einstellungsdatei sichern kann.
Er verwendet ein isoliertes Rudolstadt-2026-Profil, sichert das Original zusätzlich
im privaten Test-App-Verzeichnis und prüft jeden Kopiervorgang einschließlich der
Wiederherstellung. Bei einem Prozessabbruch bleibt diese Sicherung erhalten.

```sh
./gradlew :androidApp:assembleDebug :androidScreenshotTests:assembleDebug
adb -s "$ANDROID_SERIAL" install -r androidApp/build/outputs/apk/debug/androidApp-debug.apk
adb -s "$ANDROID_SERIAL" install -r androidScreenshotTests/build/outputs/apk/debug/androidScreenshotTests-debug.apk
adb -s "$ANDROID_SERIAL" shell am instrument -w -r \
  -e class de.leongeorgi.rudolstadt.screenshots.PersonalPlanTests \
  -e screenshotLocale de \
  de.leongeorgi.rudolstadt.screenshots/androidx.test.runner.AndroidJUnitRunner
```

App-Sprache passend zum Argument `de` bzw. `en` einstellen. Hell/Dunkel und
Schriftgröße werden vom Emulator übernommen. Der Test meldet den Bilderordner
als `screenshotDirectory`; PNGs und UI-Hierarchien liegen zusammen. Der Sketch-
Entwurf verwendet Beispieldaten: beim Kanalvergleich denselben Inhalt oder klar
benannte Komponentenausschnitte verwenden, keine vollständige Pixelgleichheit
bei anderen Konzertzeiten oder Empfehlungen behaupten.
Für den ersten Programmeinstieg gilt auf kalten Emulatoren ein Zeitlimit von
drei Minuten; nachfolgende Elemente müssen innerhalb von 20 Sekunden erscheinen.
Es gibt keine automatischen Test-Wiederholungen.
Der [Umsetzungsbericht vom 4. November 2026](../design/implementation-mein-plan-android-2026-11-04/verification.json)
enthält die geprüften Zustände, UI-Aufnahmen und die Kanalvergleiche der
gemerkten und empfohlenen Konzertzeilen. Bei großer Schrift wird die Zeitspalte
nach dem tatsächlich gemessenen Text bemessen, damit Uhrzeiten einzeilig bleiben.

## Lokal: iOS

Voraussetzungen: Xcode, JDK 17 für den Build, Python 3.10 oder neuer und ein dedizierter
Simulator. Normale Simulator-Signierung einschließlich App-Entitlements bleibt
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
Netzwerk-Refresh und Firebase, setzt Screenshot-Einstellungen zurück und erstellt
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

Für kleine UI-Änderungen genügt eine kurze Sichtprüfung der aktualisierten App
im Simulator oder Emulator. Dabei die betroffene Ansicht im relevanten Zustand
prüfen. Sketch-Exporte und Differenzbilder sind dafür optional. Für App-Starts
und Screenshot-Tests unter iOS gelten die [Freigaberegeln](../iosApp/AGENTS.md#build-and-verification).

Der vollständige Vergleich mit Sketch-Exporten, passenden Aufnahmen und
Differenzbildern ist nur bei einer gezielten Designabnahme erforderlich.

Der Badge auf der Freundesseite öffnet auf iOS und Android das Profilmenü.
Dort lassen sich Name und Badge-Farbe in einem Sheet bearbeiten. Das Menü führt
außerdem zur Schlüsselverwaltung für Schlüsselkonten, zum Abmelden und zur
Kontolöschung. Die Synchronisierung startet über die Toolbar der Freundesseite,
die bei einem Fehler eine Meldung anzeigt. Die aktuellen Entwürfe stehen auf
**Freunde · Abläufe · Firebase**. Die folgenden Berichte vom 5. November
dokumentieren den früheren Navigationsstand.

Die Freundesplanung vom 5. November 2026 liegt in Sketch auf
**Freunde · Abläufe · Firebase**. Die Hauptseite zeigt Empfehlungen und darunter
Freunde. Das Plus öffnet Einladung und Scanner, der Avatar Profil und Konto.
Freigabeeinstellungen und manuelle Einladungslink-Eingabe sind auf Nutzerwunsch
aus dem Konzept entfernt; eingehende Links führen direkt zur Einladungsansicht.
Je 15 iOS-/Android-Zustände, Vorschaubilder und der geprüfte Navigationsgraph
liegen unter `design/previews/friends-firebase-2026-11-05/`. Die Datei wurde
gespeichert, erneut geöffnet und visuell geprüft. Dies ist eine Sketch-Planung;
sie belegt keinen neuen Simulatorabgleich und ändert keine Backend-Datenregeln.

Die Android-Freundesentwürfe wurden anschließend mit Material-Komponenten
überarbeitet: große App-Bar, gefüllte Künstlerkarten, segmentierte Freundeslisten,
Vibrant-Menüs, beschriftete Outlined-Textfelder und 56-pt-Aktionsbuttons.
Die 15 aktuellen Android-Vorschauen und die Prüfung liegen unter
`design/previews/friends-material-expressive-2026-11-05/`; die früheren Bilder
bleiben als Vergleich erhalten. Die gespeicherte Datei wurde erneut geöffnet,
alle Android-Zustände visuell geprüft und die 30 Prototyp-Verbindungen validiert.
Die 15 iOS-Frames sind gegenüber der Sicherung strukturell unverändert.
Diese Überarbeitung betrifft ausschließlich die Sketch-Planung.

Die Freundesoberflächen sind anschließend in SwiftUI und Jetpack Compose
umgesetzt worden: Empfehlungen vor Freunden, zwei Toolbar-Menüs sowie getrennte
Profil- und Einladungsansichten. Die manuellen Einladungsfelder entfallen.
Die Implementierung verwendet echte Programmdaten und die gemeinsame
Empfehlungslogik; Beispielprofile und QR-Beispiele aus Sketch werden nicht
als Produktdaten übernommen. Android verwendet den nativen Google-Code-Scanner;
dessen Fehleransicht bietet einen erneuten Versuch an. Die Einladungsannahme
behält den bestehenden Hinweis auf geteilte Merker/Bewertungen und private Notizen.
Der anschließende Simulator-Abgleich liegt unter
[Freunde: Sketch / Simulator](../design/implementation-friends-2026-11-05/index.html).
Er umfasst je acht Zustände auf iPhone 17 Pro mit iOS 27.0 und Android 36,
Deutsch und helle Darstellung: Hauptseite, beide Menüs, Einladung, Profil,
Farbauswahl, Freundesdetail und Empfehlungsliste. Vorher-/Nachher-Aufnahmen,
Kanalbilder, RGB-Differenzen und Quellen stehen zusammen im Bericht.
Die Quellen wurden bei identischer Auflösung und 3× ohne Ausrichtung,
Verschiebung oder Unschärfe verglichen. Die Entwürfe enthalten andere
Beispielprofile und Künstler; vollständige Pixelgleichheit wird nicht behauptet.
Der Bericht nennt auch nicht aufgenommene Zustände und native Systemunterschiede.

Die spätere [Korrektur zu nativen Komponenten](../design/implementation-friends-native-2026-11-05/index.html)
ersetzt die geometrisch erzwungenen Toolbar-, Formular- und Menüanpassungen.
SwiftUI bestimmt Toolbar-Gruppierung, Formularzeilen und Bestätigungsaktionen;
Material bestimmt Menüanker, Standardformen und Schriftrollen. Die älteren
Differenzbilder dokumentieren den vorherigen Stand und gelten nicht als aktuelle
Layoutvorgabe. Auch diese Korrektur wurde in acht Zuständen je Plattform geprüft.

`FriendsLayoutTests` nutzt auf beiden Plattformen die reguläre Navigation und ein
vorbereitetes Entwicklungskonto. Der allgemeine Screenshot-Modus bleibt dabei aus,
da er Firebase deaktiviert. iOS erhält `FRIENDS_TEST_KEY` ausschließlich über die
private Test-Runner-Umgebung. Android liest `credentialsFile` aus dem privaten,
vorher per ADB bereitgestellten JSON (`key`); den Schlüssel nicht als Shellargument
oder in Logs übergeben. Nur dedizierte Simulatoren verwenden. Die Tests legen eine
Einladung an und ersetzen sie nach der Aufnahme wieder, damit abgebildete QR-Codes
ungültig sind. Name, Farbe, Merker, Bewertungen und Notizen werden nicht verändert.
Android schaltet im isolierten Testgerät dynamische Farben über Einstellungen ab,
um die Markenpalette mit Sketch zu vergleichen. Rohes xcresult und Zugangsdaten
bleiben außerhalb des Repos; nur die benannten Bild- und Navigationsanhänge exportieren.

Der Konto-Abgleich vom 5. November 2026 liegt in
`design/implementation-account-ios-2026-11-05/`: sieben iOS-Zustände auf
iPhone 17 Pro mit iOS 27.0, Deutsch und heller Darstellung.
`verification.json` dokumentiert die erfolgreichen gezielten UI-Tests,
Testkonto-Löschung, korrigierte Implementierung und verbleibende Unterschiede.
`comparison-before/` vergleicht den ursprünglichen Stand;
`comparison-after/` die überarbeiteten Sketch-Referenzen mit den endgültigen
Simulatoraufnahmen. Die Quellen bleiben unverschoben und unskaliert.
Live-Nachrichten, Beispielprofile und ungültige QR-Beispiele sind im Bericht
ausgewiesen. Dieser Vergleich belegt keine vollständige Pixelgleichheit und
keine visuelle Abnahme von Android, Dark Mode oder großer Schrift.

Grundlage des Vergleichsverfahrens ist der iOS-Abgleich vom 3./4. November 2026.
Der [Vergleichsbericht](../design/audit-2026-11-03/index.html) enthält Quellen,
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
Neue Simulatoraufnahmen für die Designabnahme folgen nach Freigabe dem
Capture-Pfad oben und verwenden keine zusätzlichen Produktions-Navigationshilfen.

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

### Zeitplan · Detailüberarbeitung vom 4. November 2026

Die Sketch-Zeitpläne für beide Plattformen verwenden 75 pt/dp pro Bühne,
58 pt/dp für die Zeitachse und 71 pt/dp breite Karten: je 2 pt/dp Abstand zur
Spaltengrenze. Bühnenkennzeichen, Namen und Karten teilen dieselbe Mittelachse.
Die Karten erhalten 4 pt/dp horizontalen Innenabstand. iOS verwendet SF Pro
11,5/15 für kompakte Namen und glatte 4-pt-Rundungen; Android verwendet die
installierte Roboto-Entsprechung „Rudolstadt Android UI“ mit 12/16 für Namen,
Mono 11/16 für Zeiten und 8-dp-Rundungen. Lange Namen erhalten passende Umbrüche
und sichtbare Auslassungen statt einer kleineren Ersatzschrift. Die gemeinsamen
Kartenquellen, Textstile, Bühnenbeschriftungen und Zoom-Beispiele sind angepasst.

Dies ist eine Designüberarbeitung in Sketch. Der
[Prüfbericht](../design/previews/schedule-refinement-2026-11-04/verification.json)
und die Kanalbilder vergleichen Sketch vor und nach der Änderung; sie belegen
keinen neuen Simulator-/Emulator-Abgleich. Schwarz bedeutet gleiche Graustufen,
Magenta eine hellere und Grün eine dunklere Nachher-Fläche, mit Verstärkung 3.
Die Exporte sind unverändert bei 2× verglichen, ohne Ausrichtung oder Maskierung.
Position und Höhe aller 43 Timeline-Karten sowie die datierte Screenshot-Referenz
bleiben erhalten. Alle Seiten und Ebenen sind erhalten; Änderungen betreffen nur
„Schedule“, zugehörige Quellen in „Symbols“ und gemeinsame Textstile. Die Datei
wurde gespeichert, geschlossen und erfolgreich neu geöffnet.

### Zeitplan · Korrektur der Datenbasis

Die erste Detailüberarbeitung enthielt handgeschriebene Kurzformen und ungeprüfte
Beispieldaten. Diese Bilder bleiben als historischer Vorher/Nachher-Stand erhalten;
sie sind kein Nachweis korrekter API-Inhalte. Der korrigierte Stand ist unter
`design/previews/schedule-api-correction-2026-11-04/` dokumentiert.

Für alle Entwürfe zuerst den Datenvertrag prüfen und die verwendeten Datensätze
mit stabilen IDs festhalten. Namen, Bühnen, Startzeiten und Tags aus den Quellen
übernehmen. Den vollständigen Künstlernamen erhalten; visuelle Kürzung ausschließlich
als aus Breite, Schrift und Zeilenlimit berechneten Präfix mit Endauslassung behandeln.
Keine Wörter austauschen, freie Kurzformen oder manuelle Trennstriche ergänzen.
Die Sketch-Karten speichern die vollständigen Quellwerte und IDs zusätzlich in
`scheduleAPI`-Ebenenmetadaten; `api-fixture.json` und `bindings.json` halten die
Zuordnung und gerenderten Texte prüfbar fest.

Der Abgleich nutzt den mitgelieferten API-Snapshot
`shared/src/commonMain/resources/FestivalBackup/2026_rudolstadt_data.json`.
Ein Live-Abruf war in dieser Sitzung nicht erreichbar. Korrigiert wurden unter
anderem Rastak (Termin 128, Samstag 16:00, auch die Android-Rasterposition) und
The String Company (Termin 195, Samstag 17:00 auf dem Schulplatz).

Die vergrößerte AltBadSeer-Musi-Karte basiert auf Termin 171. Dieser Termin hat
keine Tags (`tags: []`); das frei eingesetzte „KONZERT“-Tag entfällt.
Das Herkunftsland kommt aus dem API-Ländercode `AUT`. Schlagwörter und Kurztext
stammen aus `extra_data.json`, das auch die App einbindet, und werden ausdrücklich
als zusätzliche Datenquelle geführt. Fehlende optionale Felder ausblenden,
anstatt Ersatzinhalte zu formulieren. Gespeichert/Bewertungen gehören zum
Profilzustand. Die Rudolstadt-API liefert keine bestätigten Dauern; Kartenhöhen
stellen die bestehenden Planungsschätzungen dar und begründen keine Endzeiten.

Die Bühnenbezeichnung ist ein einzelner API-String, etwa „Große Bühne Heinepark“.
Sie bleibt in Sketch ein einzelner Textlayer mit einem einheitlichen Stil über
alle Zeilen. „Heinepark“ und „Markt“ erhalten keine separate Untertitelrolle.
Das gilt für Android und iOS; nur der automatische Umbruch hängt von der
verfügbaren Breite ab. Die Korrektur und die zugehörigen Kanalbilder liegen unter
`design/previews/schedule-stage-labels-2026-11-04/`.

### Zeitplan · Umsetzung in den Apps vom 4. November 2026

Die überarbeiteten Karten und Bühnenüberschriften sind in iOS und Android
umgesetzt. Beide verwenden jetzt 71 pt/dp Kartenbreite bei 75 pt/dp Spaltenraster
und 4 pt/dp Innenabstand in der Standardansicht. Bühnenname, Kennzeichen und
Karte bleiben auf derselben Mittelachse. iOS verwendet 10 pt für Bühnenüberschriften,
11,5 pt für kompakte Namen und einen 16-pt-Bewertungsbereich mit ausreichend
reservierter Höhe für zweizeilige Namen. Die Detailansicht verwendet 8-pt-Abstände
zwischen Herkunft, Schlagwörtern und Kurztext. Automatisches Verkleinern dieser
Texte entfällt. Android verwendet 12/16 sp für Kartennamen mit 0,1 sp Laufweite,
11/14 sp für den vollständigen Bühnenstring und 4 dp Abstand zwischen den
Kartentexten. Die plattformspezifischen Rundungen bleiben 4 pt glatt auf iOS und
8 dp auf Android.

Die frühere Einordnung einzelner Datenwerte muss korrigiert werden: Ein frischer
Android-Abruf der Live-API liefert Rastak (128) um **15:30**, RIAN (129) um
**18:30** und **Antoní** für Termin 195. Der ältere mitgelieferte Snapshot enthält
16:00, 19:00 und The String Company. Diese Live-Werte sind keine
Implementierungsfehler. Die Apps behalten ihre API-Daten; Tests lesen ihre
Erwartungen aus derselben geladenen Quelle. Für künftige Vergleiche Quelle,
Abrufzeitpunkt, stabile IDs und Profilzustand festhalten. Eine Abweichung zum
Snapshot rechtfertigt keine fest einprogrammierten Ersatzwerte.

Der native iOS-Test nutzt den dokumentierten deterministischen Screenshot-Modus,
Android einen frischen privaten Emulator mit Live-Cache. Geprüft sind 20 gezielte
iOS- und 34 Android-Unit-Tests sowie je ein nativer UI-Test. iOS prüft außerdem
Detailzoom, Pinch, Reset und gescrollte Spaltenausrichtung; Android vollständige
API-Namen, Startzeit, Ausrichtung, Konzertnavigation und Reset.

[Prüfbericht](../design/implementation-schedule-2026-11-04/verification.json),
[iOS-Kanalbild](../design/implementation-schedule-2026-11-04/ios-channels.png) und
[Android-Kanalbild](../design/implementation-schedule-2026-11-04/android-channels.png)
enthalten die neuen nativen Aufnahmen. Die Quellen bleiben unverschoben und
unskaliert; identische Komponenten werden zusätzlich mit demselben Bildrechteck
verglichen. Schwarz bedeutet gleiche Graustufen, Magenta eine hellere und Grün
eine dunklere native Fläche, verstärkt um Faktor 3. Absolute RGB-Differenzen
bleiben zusätzlich erhalten. Nur im iOS-Kanalbild sind die oberen 186 Pixel der
Systemleiste maskiert; das Android-Kanalbild ist vollständig unmaskiert.

Eine vollständige Pixelgleichheit der ganzen Seite ist damit nicht belegt:
Live-Inhalte und Nachrichtenzähler unterscheiden sich, ebenso Androids native
Tab-Verteilung, Auswahlhintergrund, vier Toolbar-Aktionen und untere Navigation
sowie die iOS-Bühnenkennzeichen mit Verlauf und Kontur. Kleine Unterschiede an
Schriftkanten, den iOS-Zeitachsen-Ziffern und einzelnen automatischen Umbrüchen
bleiben sichtbar. Der iOS-Nachrichtenbanner rotiert zwischen anderen Artikeln.
Diese Unterschiede sind im Bericht benannt und
werden nicht durch nachträgliches Ausrichten oder weitere Masken versteckt.
