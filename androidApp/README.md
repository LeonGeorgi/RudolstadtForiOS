# Native Android-App

Jetpack Compose mit Material 3 und adaptiver Navigation (Navigationsleiste auf
Telefonen, Rail bei größeren Fenstern). Ohne Android Studio nutzbar.

Enthalten sind Künstler mit Suche, Genre-/Typfiltern, Raster und 3D-Globus,
Künstlerdetails mit Musikvorschau, Videos, ähnlichen Künstlern, Bewertungen und
Notizen; Programm als Liste und Zeitplan, Konzertmerker, Planvorschläge mit
Wege- und Konfliktprüfung; Bühnen-/Geländekarten und Detailprogramme; Nachrichten
mit Lesestatus und optionalen Hintergrundbenachrichtigungen; Archive,
Festivalinformationen sowie Darstellung und App-Sprache.

Die UI verwendet direkt die kanonischen Objekte und Berechnungen aus `shared`.
Künstlerindex, Nachrichtenverweise, Filter, Tageszuordnung, Dauer, Empfehlungen
und Wege bleiben in Kotlin. Die Apple-Oberfläche verwendet denselben Künstlerindex
und dieselbe Erkennung erwähnter Künstler und Bühnen. Native Adapter übernehmen
DataStore, WorkManager, Media3, Intents und MapLibre. Der Offlineplan
liegt einmal in `shared`, einschließlich PDF und Hintergrundbild für Apple.

Persönliche Daten liegen transaktional in `files/datastore/rudolstadt.json`,
getrennt nach Festival-Ausgabe. Unlesbare Dateien werden nicht zurückgesetzt;
die App zeigt einen wiederholbaren Fehler. Caches liegen getrennt in `cache`.
Ein fehlgeschlagener Abruf ersetzt keinen bestätigten Datenstand; Quelle und
Fehler sind sichtbar. Fremde Veranstaltungsjahre werden vor Übernahme abgewiesen.
Archive bleiben schreibgeschützt. Die Planung verwendet die echte Uhrzeit;
vergangene Festivals erhalten keine künstlichen zukünftigen Vorschläge.

CloudKit, Freunde, Apple-Watch-Integration und StoreKit-Spenden gehören zur
Apple-Plattform und sind auf Android nicht eingebaut.

Die Stadtkarte verwendet OpenFreeMap-Vektorkacheln mit einer Festival-Farbgestaltung
auf Basis von Positron, MapLibre-Cache und dem integrierten Attributionsdialog (OpenMapTiles,
OpenStreetMap). Der Dienst benötigt keinen API-Schlüssel. Bühnen und Standort
bleiben separate lokale Overlays. Alle Karten und Downloads teilen einen HTTP-Client
mit App-User-Agent und höchstens vier parallelen Requests.

Die Farbgestaltung orientiert sich am offiziellen Lageplan: warmer Cremegrund,
ockerfarbene Hauptstraßen, Wasserblau, helle Grünflächen und dunkelrote Bühnenmarker.
Gebäude, Nebenstraßen und Fußwege werden beim Hineinzoomen deutlicher; Straßen- und
Ortsnamen bleiben erhalten. Eine dunkle Variante folgt der gewählten App-Darstellung.
`FestivalMapStyle` ändert lokal die [MapLibre-Layer-Eigenschaften](https://maplibre.org/maplibre-style-spec/layers/)
und ergänzt eine Straßenkontur. Geometrie, Schriftarten, Kachelquelle und Offline-Paket
bleiben dieselben; ein Stilwechsel benötigt keinen neuen Kartendownload. Die Karte
übernimmt keine schematischen Straßenverläufe oder Anfahrtsrouten aus dem Druckplan.

Über die Karten-Toolbar lässt sich die Stadtkarte für Rudolstadt ausdrücklich
herunterladen, pausieren, fortsetzen und löschen. Das Paket umfasst 50.685–50.755° N
und 11.285–11.405° E, Zoom 10–16, einschließlich Stil, Schriften und Symbolen.
Die Vektorquelle liefert ihre höchste Datenstufe auch für größere Darstellungen;
außerhalb des Pakets wird bei bestehender Verbindung normal nachgeladen. Der Download
pausiert im Hintergrund und startet nach einem Neustart nicht automatisch. Fertige
und teilweise geladene Pakete bleiben in MapLibres Offline-Datenbank erhalten und
stehen allen Stadt- und Bühnenkarten zur Verfügung. Die Oberfläche zeigt Fortschritt
und gespeicherte Ressourcenbytes; das ist keine Messung der übertragenen Netzwerkbytes.

[OpenFreeMaps Nutzungsbedingungen](https://openfreemap.org/tos/) erlauben bis zu
3.000 Kacheln oder 50 MB pro Offline-Download. Der feste Ausschnitt bleibt bei Zoom 16
unter 1.000 geografischen Kacheln; zusätzliche Abbruchgrenzen bei 2.800 Kacheln und
45 MB Ressourcenbytes lassen Platz für laufende Requests. Kein automatischer
Gebietsdownload und kein Bulk-Download der bisherigen OSM-Rasterquelle.
Beim Emulatortest am 29. Oktober 2026 enthielt das vollständige Paket 62
Vektorkacheln mit zusammen rund 1,4 MB gespeicherten Nutzdaten. Insgesamt waren es
rund 19,4 MB: MapLibres Offline-Download lädt zusätzlich umfangreiche Zeichenbereiche
für die drei im Stil verwendeten Schriften (rund 17,9 MB). Beim normalen Online-Aufruf
werden nur die benötigten Zeichenbereiche geladen. Diese Zahlen sind gespeicherte
Ressourcenbytes, kein Vergleich der übertragenen Netzwerkbytes mit Rasterkacheln.

Der Künstler-Globus und der Ludwigsburger Geländeplan funktionieren weiterhin
mit gebündelten Ressourcen. Nachrichtenprüfungen laufen optional
über WorkManager (frühestens alle 15 Minuten, Zeitpunkt durch Android bestimmt).
Die erste erfolgreiche Prüfung setzt die Baseline ohne historische Meldungen.
Bei sichtbarer App werden keine zusätzlichen Systembenachrichtigungen ausgelöst.

## Navigation und Gestaltung

Die Hauptbereiche verwenden eigene verschachtelte Navigationsgraphen. Beim Wechsel
bleiben Detailseite und Scrollposition erhalten. Die adaptive Expressive-Navigation
verwendet die kurze Navigationsleiste beziehungsweise die breite Navigation Rail
und bleibt bei Künstlern, Bühnen und Entdeckungsseiten erreichbar. Vollbildkarten,
Fotos und Videos geben dem Inhalt den Bildschirm frei. Das folgt Androids
[Multiple-Back-Stack-Muster](https://developer.android.com/guide/navigation/backstack/multi-back-stacks)
und der [adaptiven Navigation](https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-and-nav-patterns).

Die Künstleransicht bündelt die Darstellungswahl im Überlaufmenü und bietet Liste,
großes und kompaktes Raster. Umfangreiche Filter sind als durchsuchbare
Einfachauswahl in einem modalen Material-Sheet erreichbar; aktive Filter lassen
sich einzeln entfernen. Rasterdichte und Programmfilter werden gespeichert,
Programmfilter getrennt pro Festivalausgabe. Bestehende Einstellungen bleiben lesbar.
Die Komponenten folgen den [Material-3-Rollen für Chips und Auswahlzustände](https://developer.android.com/develop/ui/compose/components/chip).

Konzertlisten zeigen Künstlerbilder, Bewertungen und Kategorien. Langes Drücken
öffnet ein Material-Aktionssheet mit Konzertkontext, Kurzbeschreibung und direkten
Aktionen zu Künstler und Bühne. Die Timeline zeigt die Startzeit schon bei einer
normalen einstündigen Veranstaltung; größere Felder ergänzen Bewertung, Kategorie,
Herkunft und Kurztext. Farben, Formen und Bewegung stammen aus dem bestehenden
[Material-3-Expressive-System](https://developer.android.com/develop/ui/compose/designsystems/material3).

Der Globus zeigt nach Länderwahl die Künstler in einem nicht modalen, verschiebbaren
Bottom Sheet; bei breiten Fenstern steht die Liste neben dem Globus. Länderwechsel
bleiben ohne Verlassen der Karte möglich. Zurück wechselt zuerst zur Länderauswahl.
Drehung und Zoom bleiben beim Öffnen eines Künstlers erhalten.

„Mein Standort“ startet erst nach einer bewussten Aktion und erteilter Berechtigung
eine Ortung während der sichtbaren Kartenansicht. Fixes älter als zwei Minuten
werden ausgeblendet; für den schnellen Einstieg wird höchstens eine 15 Sekunden
alte Position verwendet. Das Verlassen der Karte und der Wechsel in den Hintergrund
beenden die laufenden Standortanfragen. Die Kamera zentriert auf Anforderung und
bleibt anschließend frei bedienbar. AndroidX
[LocationManagerCompat](https://developer.android.com/reference/kotlin/androidx/core/location/LocationManagerCompat)
übernimmt die Versionsanpassung ohne zusätzliche Google-Play-Services-Abhängigkeit.

Musikvorschauen zeigen den Fortschritt direkt im Play-Button neben den Künstlerlinks.
Nach dem Laden lässt sich über die Titel-/Laufzeitzeile ein bedienbarer Slider
aufklappen. Der Player gehört zur Detailseite und läuft beim Scrollen weiter.
YouTube-Videos werden erst nach Antippen als eingebetteter Player mit HTTPS-Origin
geladen; Vollbild und ein externer YouTube-Link bleiben verfügbar. Beim Verlassen
der Ansicht oder Wechsel in den Hintergrund pausiert die Wiedergabe. Die Einbettung
verwendet die [offizielle YouTube-IFrame-API](https://developers.google.com/youtube/iframe_api_reference).

Die Oberfläche verwendet Material 3 Expressive mit `MaterialExpressiveTheme`,
`MotionScheme.expressive()`, semantischen Farbrollen und optionalen dynamischen
Farben. Material 3 ist gezielt auf `1.5.0-alpha07` festgelegt: Diese Version stellt
die öffentlichen Expressive-APIs bereit und passt zur vorhandenen SDK-36-/AGP-8-
Toolchain. Die aktuelle 1.5-Beta verlangt SDK 37 und AGP 9.1; dieses UI-Update
stellt nicht die gesamte Build-Toolchain um. Referenzen (Stand 29. Oktober 2026):
[Material 3 in Compose](https://developer.android.com/develop/ui/compose/designsystems/material3)
und [Material-3-Release-Notes](https://developer.android.com/jetpack/androidx/releases/compose-material3).

Suche und Filter sind über die Toolbar erreichbar. Der Festivaltitel öffnet den
Datenstatus; Archiv-, Fallback- und Fehlerhinweise bleiben sichtbar. Gemeinsame
Bildkomponenten zeigen Lade- und Ersatzdarstellungen; Raster und Detailansichten
verwenden große Fotos. Künstlerdetails zeigen auf Telefonen ein randloses quadratisches
Foto mit Länderchips und kompakter Bewertung. Beim Scrollen blendet die Identität im
Foto aus und der Name erscheint in der App-Bar. Kurzbeschreibung und persönliche
Notiz stehen nebeneinander; Auftritte folgen als kompakte Zeilen mit Zeitkacheln,
Konflikten und separaten Merkern. Video, Beschreibung, Genres und ähnliche Künstler
bleiben direkt erreichbar. Der zoombare Bildbetrachter und zwei Spalten bei
geeigneter Fensterbreite bleiben verfügbar.
Bei großer Schrift stehen Name und Aktionen außerhalb des Fotos; der Zeitplan
wechselt automatisch zur lesbaren Liste, ohne die gespeicherte Ansicht zu ändern.

Die Timeline lässt sich horizontal und vertikal per Zwei-Finger-Geste zoomen;
der Bezugspunkt bleibt dabei unter den Fingern. Beide Achsen können zusätzlich
über zugängliche Regler eingestellt werden. Konzertfelder zeigen abhängig vom
Platz weitere Informationen, Bewertungen, Merker und bestätigte Zeitangaben. Die
aktuelle Uhrzeit wird während des Festivaltags markiert. Langes Drücken öffnet
in Liste und Timeline dieselben Schnellaktionen; Rasterbilder erlauben direkte
Bewertungen. Konzerte ohne feste Zeit sind separat erreichbar.

Bei Festivals mit Konzertdetails öffnen Termine eine eigene Detailseite. Der
zentrierte Kopf zeigt eine skalierbare Zeitkachel, die Bühne mit Nummer und den
Künstler mit Avatar. Die Künstlerzeile ist stärker gewichtet. Künstler- und Bühnenzeile öffnen die
jeweiligen Details mit dem aktuellen Termin als Kontext. Zusatztexte und eine große Karten-Vorschau folgen darunter. Merken
bleibt über die App-Leiste erreichbar. Geschätzte Dauern erscheinen weder als
Text noch als Hinweis oder in der Sprachausgabe; die Planung verwendet sie weiter.
„Konzertdetailseiten immer anzeigen“ in den Einstellungen ermöglicht diese Seite
auch ohne Festival-Zusatzinhalte. Die Option ist zunächst ausgeschaltet und gilt
für alle Festivalausgaben; sie aktiviert kein Daten-Feature.

Kartenmarker öffnen das Bühnenprogramm in einem verschiebbaren Material-Sheet.
Die Karte bleibt bedienbar. In breiten Fenstern steht das Programm in einer
Seitenfläche. Eine Ortsliste bietet denselben Zugang ohne Karten-Gesten.

Die Zeitliste hält die Uhrzeiten beim horizontalen Scrollen und die Bühnenköpfe
beim vertikalen Scrollen fest. Bei geringer Fensterhöhe liegen Filter und Zoom
in der oberen Leiste, sodass der Zeitplan im Querformat Platz behält. Bühnen tragen ihre Nummer beziehungsweise ein
passendes Symbol in Listen und Karten. Konzerte öffnen den Künstler mit
hervorgehobenem Termin; von dort geht es zur Bühne mit demselben Termin und
passendem Tag. Die Vollbildkarte lässt sich zurück zur Bühne schließen.
Länder und Genres führen zu eigenen Künstlerlisten, ohne die Hauptfilter zu ändern.
Bewertungen verwenden ein Material-Bottom-Sheet mit benannten Optionen; ungespeicherte
Notizen fragen vor dem Verwerfen nach.

Der Globus ist eine native OpenGL-ES-Kugel mit Drehung, Zoom und Länderwahl aus den
gebündelten GeoJSON-Daten. Eine Länder-Liste bietet denselben Zugang ohne Gesten.
Compose bleibt für die Bedienoberfläche zuständig; es gibt keine weitere 3D-Engine.
Als Gestaltungsreferenzen dienten die offiziellen App-Screenshots von
[Read You](https://github.com/ReadYouApp/ReadYou) und
[Gramophone](https://github.com/FoedusProgramme/Gramophone).

## Auf diesem Mac starten

Android Studio ist nicht erforderlich. Benötigt werden JDK 17 und das Android-SDK
unter `~/Library/Android/sdk`. Der eingerichtete ARM64-Emulator heißt
`Rudolstadt_API_36` und verwendet Android 16 / API 36 mit Google APIs.

Im Projektstamm:

```sh
./scripts/android/run-emulator.sh
```

Das Skript baut die Debug-App, startet beziehungsweise verwendet diesen Emulator,
installiert die APK und öffnet die App. Es beendet keine anderen
Emulatoren. Logs liegen unter `artifacts/android/`. Für einen anderen SDK-Pfad
`ANDROID_HOME` setzen; AVD und Port lassen sich mit `ANDROID_AVD_NAME` und
`ANDROID_EMULATOR_PORT` überschreiben.

## SDK und virtuelles Gerät auf einem weiteren Mac einrichten

Die offiziellen [Android-Kommandozeilenwerkzeuge](https://developer.android.com/studio#command-line-tools-only)
unter `$ANDROID_HOME/cmdline-tools/latest` installieren. Danach:

```sh
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export ANDROID_HOME="$HOME/Library/Android/sdk"
android_cli="$ANDROID_HOME/cmdline-tools/latest/bin/android"
"$android_cli" --sdk="$ANDROID_HOME" sdk install platforms/android-36
"$android_cli" --sdk="$ANDROID_HOME" sdk install build-tools/35.0.0
"$android_cli" --sdk="$ANDROID_HOME" sdk install platform-tools
"$android_cli" --sdk="$ANDROID_HOME" sdk install emulator
"$android_cli" --sdk="$ANDROID_HOME" sdk install system-images/android-36/google_apis/arm64-v8a
echo no | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd \
  --name Rudolstadt_API_36 --package 'system-images;android-36;google_apis;arm64-v8a' \
  --device pixel_7a
```

Das ARM64-Systemabbild ist für Apple Silicon. Auf Intel-Macs ein passendes
x86_64-Abbild wählen. Der Emulator kann regulär über sein Fenster beendet werden.

## Screenshots in GitHub Actions

Der Workflow **Android Screenshots** baut die APK einmal und nimmt anschließend
auf einem Pixel 7 Pro und Pixel Tablet jeweils Deutsch und Englisch in Hell und Dunkel
auf. Er läuft manuell sowie bei Android-relevanten Pull Requests und Änderungen
auf `master`. Pro Gerät gibt es ein Screenshot-Artefakt mit den Ordnern
`de/light`, `de/dark`, `en/light` und `en/dark`: Zeitplan, Künstler, Orte und Mehr.
UI-Automator-Berichte, Logs und Fehlerbilder liegen im separaten Diagnose-Artefakt.
Die Aufnahmen laufen mit UI Automator 2.4. Lokale Aufrufe und Details stehen in der
[Screenshot-Anleitung](../docs/screenshots.md).

Vollständig erfolgreiche Läufe auf `master` veröffentlichen zusätzlich alle 32
Originale und optimierte Vorschaubilder im Branch `screenshots`. Die Haupt-README
bindet diese stabilen Bildadressen ein; die Galerie im Screenshot-Branch zeigt
alle Sprachen und Darstellungen. Fehlgeschlagene oder PR-Läufe ersetzen keine
veröffentlichten Bilder. Die bisherigen iPhone-/iPad-Bilder verwenden weiter die
bestehende GitHub-Pages-Galerie.

Lokal mit JDK 17 und den gebauten App-/Test-APKs auf einem dedizierten,
bereits gestarteten Android-Emulator ab API 33:

```sh
./gradlew :androidApp:assembleDebug :androidScreenshotTests:assembleDebug
ANDROID_SERIAL=emulator-5554 bash scripts/android/capture-screenshots.sh
```

Der Runner installiert die APK und ändert App-Sprache, Systemdarstellung und
Statusleiste des Emulators. Er löscht keine App-Daten. Für reproduzierbare
Aufnahmen einen frischen Emulator mit der Standarddarstellung „System“ verwenden.
Programm und Karten verwenden das normale Ladeverhalten einschließlich gebündeltem
Fallback; Bilder und Kartenkacheln können Netzwerkzugriff benötigen.
`PREBUILT_APK_PATH`, `NATIVE_TEST_APK_PATH`, `LOCALES`, `OUTPUT_ROOT` und
`DIAGNOSTICS_ROOT` sind optional.
Lokale Ausgaben landen unter `artifacts/screenshots/android/`.
Ein fehlgeschlagener Instrumentation-Test oder ein unvollständiger Bildsatz beendet
den Lauf mit Fehler. Nur ein vollständiger erfolgreicher Satz wird übernommen.

## Bauen und prüfen

```sh
export ANDROID_HOME="$HOME/Library/Android/sdk"
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
./gradlew :androidApp:assembleDebug :androidApp:testDebugUnitTest :androidApp:lintDebug
./gradlew checkKotlinFormat :shared:verifyAndroidResources
```

Die Android-Modultests laden alle sieben Ausgaben aus `shared`, prüfen
Kataloge, gemeinsame Ressourcen, Planungsgrenzen und die transaktionale
Speicherung persönlicher Daten. Die Präsentationstests sichern alte Einstellungsdateien,
ausgabenspezifische Programmfilter, die lesbare Standard-Timeline und die Gültigkeit
von Standort-Fixes ab. `:shared:jvmTest` prüft die gemeinsame Domain. Die APK liegt unter
`androidApp/build/outputs/apk/debug/androidApp-debug.apk`.
