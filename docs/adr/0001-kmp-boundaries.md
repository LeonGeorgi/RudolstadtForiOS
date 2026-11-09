# 0001: Native Oberflächen und gemeinsamer Kotlin-Kern

Status: umgesetzt, aktualisiert am 29. Oktober 2026.

Die damalige CloudKit- und Apple-Beschränkung ist durch
[ADR 0002](0002-firebase-friends.md) ersetzt. CloudKit ist entfernt; lokale
Speicherformate bleiben als Importgrenze lesbar.

## Entscheidung

`shared` ist ein KMP-Bibliotheksmodul mit Android-, JVM- und Apple-Targets,
einschließlich Watch-Geräte und Watch-Simulatoren.
`iosApp` enthält das vollständige native Apple-Projekt. SwiftUI, CloudKit,
WatchConnectivity, Betriebssystemdienste, native Formatierung und die bestehenden
Persistenzadapter bleiben in Swift. `androidApp` enthält die native Android-Oberfläche
mit Jetpack Compose und Material 3. Künstlerindex, Filter, Programmaufbereitung und
Planung stammen aus `shared`; Android ergänzt DataStore, WorkManager, Media3 und
MapLibre als native Adapter. CloudKit und Freundesfreigaben bleiben Apple-spezifisch.

Die Fach-Packages heißen `festival`, `planning`, `profile`, `discovery`,
`loading` und `news`. Das Package `presentation` besitzt ViewModels und App-State.
`interop` ist die Apple-Fassade über diesen APIs. Fachcode importiert keine
Interop-Klassen. Ein zusätzliches Gradle-Modul wird erst bei einer echten
unabhängigen Build- oder Abhängigkeitsgrenze benötigt.

## Werte und Fehler

Künstler (`ProgramArtist`), Veranstaltungen (`ProgramOccurrence`), Bühnen
(`ProgramPlace`), Bereiche (`ProgramArea`) und Tags (`ProgramTag`) leben als
unveränderliche Objekte in `festival`. SwiftUI verwendet diese Objekte direkt.
Swift-Typaliase ändern nur die Namen; Erweiterungen liefern `Identifiable`, native
Formatierung, URL-Werte und Präsentationsprojektionen. Der native Kontext
`FestivalData` ergänzt Apple-Dienste und Darstellungsfähigkeiten; der Ladezustand
gehört dem gemeinsamen ViewModel. Die frühere Entscheidung für eine vollständige
Swift-Wertmodellhierarchie wird damit ersetzt.

Die Kotlin-Modelle enthalten keine veränderlichen Felder. Anreicherung ersetzt
Objekte durch Kopien und verknüpft anschließend die Veranstaltungsreferenzen mit
den aktualisierten Katalogen. Daher wird ein bereits sichtbares Programm nicht
über geteilte Referenzen verändert. Die Swift-`Sendable`-Konformanzen verlassen
sich auf diesen Vertrag: gemeinsame Listen und Maps werden nach der Konstruktion
nicht verändert.

Quellenkonvertierung und Fachoperationen liefern typisierte Objekte. Der frühere
JSON-Rückweg mit Swift-Decodable-Zwischenmodellen entfällt. JSON bleibt für externe
Quellen und Cache-Dateien. Die Quellen- und Cache-Decoder haben eine explizite
Kotlin-`@Throws`-Grenze; Aufrufer behandeln Vertragsfehler als Ladefehler. Fehler
erzeugen kein leeres Ersatzprogramm und verwerfen keinen bestätigten
persönlichen Zustand. Rohdaten, UserDefaults, CloudKit-Records und Watch-Snapshots
behalten ihre Schemas.

IDs werden in Kotlin als `Long` und an der Apple-Grenze als 64-Bit-Werte behandelt.
Rückgaben mit numerischen Schlüsseln werden als typisierte Einträge exportiert:
`NSDictionary` kopiert numerische Schlüssel als `NSNumber` und verliert dabei den
Kotlin-Wrapper. Die Fachmodelle verwenden intern weiterhin normale Kotlin-Maps.

## Laden und Nebenläufigkeit

`ProgramLoadSession` entscheidet gemeinsam über frischen/stalen Cache,
Netzwerkaktualisierung und gebündelten Fallback. Ein bestätigtes Programm bleibt
bei einem fehlgeschlagenen Ersatz erhalten. Archiv- und Experimentquellen
benötigen keinen Netzwerkabruf. `CachePolicy` legt die Drei-Stunden-Grenze und
bestehenden Dateinamen fest; `HttpPolicy` klassifiziert HTTP-Status.

Das gemeinsame Repository führt HTTP-Abrufe und Parsing aus. Apple-Adapter
übernehmen Systempfade, Ressourcen und synchronen Dateizugriff einschließlich
des bestehenden PropertyList-Formats.
`RefreshGeneration` wird ausschließlich im besitzenden Actor verwendet. Der
Native-Provider prüft Abbruch und Generation vor dem Cache-Schreiben. Der
MainActor serialisiert die Aufrufe der gemeinsamen ViewModels. Deren Generationen
verhindern, dass verspätete Ergebnisse einen neueren App-State ersetzen. Der
Native-Provider behält zusätzlich seinen Schutz vor verspäteten Cache-Schreibvorgängen.

Zusätzlich zum unveränderten Rohdatenformat speichert Apple das bereits konvertierte
gemeinsame Programm als abgeleiteten Cache. Das Format `program-v2.plist` speichert
Veranstaltungsbeziehungen normalisiert per ID; Kotlin stellt daraus denselben
geteilten Objektgraphen wieder her. Der vorherige abgeleitete Cache wird bei der
nächsten normalen Cache-Ladung aus den Rohdaten ersetzt. Prüfsummen binden ihn an Rohdaten und
Zusatzdaten; App-Build und Formatversion verhindern die Wiederverwendung veralteter
Konvertierungen. Ein unlesbarer oder unpassender Cache wird aus den Rohdaten neu
erstellt. Sein Alter richtet sich weiterhin nach dem ursprünglichen Download.
Der App-Zustand stellt diesen Cache vor dem ersten SwiftUI-Bild wieder her, auch
wenn er bereits veraltet ist. Aktualisierungen laufen anschließend bei sichtbarem
Programm. Der erste Start mit einem alten Rohdaten-Cache erzeugt den abgeleiteten
Cache einmalig über den bestehenden Ladepfad.

## ViewModels und App-State

`presentation` besitzt den veränderlichen Anwendungszustand als unveränderliche
Snapshots in `StateFlow`:

- `FestivalViewModel`: Programm, Lade-/Fehlerzustand, Herkunft, Fallback,
  Download-Zeitpunkt sowie Start- und Vordergrund-Aktualisierungen.
- `RecommendationViewModel`: kohärentes Ergebnis aus Event-IDs, Dauern und
  Berechnungszeitpunkt; neue Eingaben entwerten alte Berechnungen schon während
  des Debounce.
- `ProfileViewModel`, `SyncViewModel`, `FriendsViewModel`: persönliche Werte,
  Änderungen, Versionen, ausstehende Uploads, Konflikte, Sync-Status und
  Freundesprofile. Bestätigte Fehler bleiben bis zum erfolgreichen Sync sichtbar.
- `NewsViewModel` und `NewsHistoryViewModel`: Inhalt,
  Lade-/Fallbackzustand, parallele Anfragen, Aktualisierungsgrenzen, gelesene und
  bekannte Nachrichten sowie Benachrichtigungsberechtigung auf Inhaltsebene.
- `DiscoveryViewModel`, `SchedulePreferencesViewModel` und
  `FestivalSelectionViewModel`: Suche und Filter sowie Festivalauswahl mit kompatibler Priorität der bisherigen gespeicherten Schlüssel.

SwiftUI liest die aktuellen Kotlin-Snapshots direkt. `KotlinStateStore` verbindet
synchron beobachtete Änderungen mit `objectWillChange`; sein `state`-Getter liest
`current` des ViewModels. Er speichert keinen weiteren State und konvertiert keine
Kopie für die Darstellung. Die vorherige Anbindung über Swift-`RecommendationState`
und veröffentlichte Kopien von News, Profilwerten, Freundesprofilen und Sync-Daten
ist damit ersetzt. Die Fachzustände und Zustandsübergänge bleiben in Kotlin.

`SharedFestivalProfile` und `CoreFriendProfile` sind Typaliase gemeinsamer Modelle.
Native Erweiterungen ergänzen Identität und Badge-Darstellung. Der Zeitplanfilter
nimmt `RecommendationState` und `ProfileState` direkt entgegen, einschließlich
geteilter Mengen gespeicherter Events und positiv bewerteter Künstler. SwiftUI-
Layout und View-Hierarchie bleiben erhalten; angepasst werden die Datenzugriffe.

Native Persistenzstrukturen bleiben Transportformate für UserDefaults und CloudKit,
einschließlich CK-Systemfeldern. Auch JSON-Preview-Seeds verwenden diese DTOs am
Decoder-Eingang und erzeugen daraus gemeinsame Modelle. Native Dienste erhalten
bei Bedarf Swift-IDs, Dictionaries oder `Date`; diese Werte werden nicht als zweiter
UI-State aufbewahrt. Die bestehenden gespeicherten Schemas bleiben erhalten.

Die Migration ersetzt auch die bisherigen Swift-Aufrufketten. `ProgramRecommendations`
übernimmt Vorbereitung, Dauern, Transfermatrix und Optimierung und liefert den
unveränderten gemeinsamen Ergebnistyp an `RecommendationViewModel`. Eingebaute
`TransferSource`-Implementierungen rechnen ohne Rückweg über Swift. `SchedulePresentation`
leitet den vollständigen Zeitplan-Zustand ab; die Swift-Anbindung passt nur die
nativen Lade-/Fehlerdarstellungen an. `PlanFactsCalculator` berechnet die Fakten,
die Apple in sein bestehendes Watch-Transportformat schreibt. Der alte,
ausschließlich noch getestete Swift-Projektor ist entfernt.

Metadaten, Inhalte, Künstlerdetails, Gruppen und Kategorien sind ebenfalls
Typaliase gemeinsamer Werte. `ProgramCatalogs` entscheidet über fachliche
Fähigkeiten; `RudolstadtContent` besitzt Festivalregeln, Zusatzorte und
Informationsdefinitionen. Die gemeinsame Bibliothek benötigt für diese Aufgaben
keine Swift-Servicehierarchie. Native Adapter ergänzen Lokalisierung, Foundation-
Werte, Symbole und geprüfte PDF-/Kartenressourcen.

Zusätzliche Konzertinhalte gehören ausschließlich zum optionalen
`FestivalProgram.eventDetails`-Feature. Auftritte und ihre Metadaten nehmen keine
redaktionellen Konzertinhalte entgegen. Das Vorhandensein des Feature-Blocks
aktiviert die Konzertdetailnavigation; eine leere Inhaltsliste bleibt ein
aktiviertes Feature. Tags und Programmentdeckung sind davon unabhängig.
Der normalisierte Cache migriert frühere Inhalte am Auftritt explizit in diesen
Feature-Block und prüft eindeutige, bestehende Veranstaltungsreferenzen.


Die kanonischen News-Modelle, ihre Wire-Formate und Konvertierungen liegen in
`news`; `presentation` besitzt deren State und Aktualisierungsentscheidungen.
Repository und Darstellung verwenden getrennte Controller-Instanzen mit denselben
gemeinsamen Modelltypen. Das erhält den Vertrag, dass das Löschen eines Caches
dessen Arbeitsspeicher zurücksetzt, bereits dargestellte Inhalte aber bis zur
nächsten Aktualisierung bestehen bleiben. Die Auslieferungsplanung berücksichtigt
Baseline, Vordergrund und Sprache gemeinsam, bevor Apple Benachrichtigungen
übergibt. Der frühere Kotlin→Swift→Kotlin-Snapshot-Rückweg entfällt.

`profile` liefert Änderungswerte, Versionen und Uploadpläne direkt. Native
Persistenz-DTOs und CloudKit-Systemfelder bleiben an ihren Ein-/Ausgabegrenzen;
`CachedProfileChangeVersion` erhält insbesondere das vorhandene Foundation-
Datumsformat. Neue Fachmodelle hängen nicht vom Package `presentation` ab.
`ColorMath` teilt die komplette bisherige OKHSL/OKLab-Konvertierung. Die Referenzwerte
für beide Richtungen stammen aus der vorherigen Swift-Implementierung.

Die ungenutzte Bildfarbextraktion einschließlich Cache, Palette-Modellen und
zugehörigen Tests ist entfernt. Die Künstlerdetailansicht verwendet native
Systemfarben. Die weiterhin für Timeline und Veranstaltungsvorschauen benötigte
OKHSL/OKLab-Konvertierung bleibt im gemeinsamen Kern.

`ProgramTimeline` erzeugt Zeitraster, Bühnenspalten und Lücken einschließlich der
bisherigen Behandlung überlappender Einträge. `ProgramDetails` liefert Konflikte,
Bühnentage, initiale Tagesauswahl und nahe Orte. SwiftUI zeichnet diese Ergebnisse;
native numerische Textsortierung wird als Vergleichsfunktion übergeben. Die
bisherigen Berechnungen in Views und die separate Preview-Implementierung sind
ersetzt. Gemeinsame Veranstaltungen behalten beim Anzeigen ihre Objektidentität.

`MediaLinks` interpretiert YouTube-/Apple-Music-Links und kuratierte Vorschauwahl;
`MusicPreviews` parst die Lookup-Antwort und wählt den ersten exakten Treffer.
URL-Syntax, Escaping und Prüfung nativer URL-Werte bleiben Systemadapter. Diese
liefern typisierte URL-Bestandteile beziehungsweise einen Prüfrückruf an Kotlin.
HTTP-Aufrufe und Lookup-Parsing laufen gemeinsam in Kotlin; WebKit und AVPlayer
bleiben nativ. Das Laden einer Musikvorschau
beginnt weiterhin erst auf Wiedergabeanforderung.

`PersonalPlan` und `PlanFreshnessPolicy` berechnen den nächsten Termin, die
Widget-Timeline, Tagespläne und Datenalter. Die Watch bindet das gemeinsame
Framework selbst ein. Swift adaptiert ihre bestehenden Codable-Transportwerte
und die Ergebnis-IDs; WatchConnectivity, Kompression, Dateiaustausch, native
Fehlerdarstellung und WidgetKit bleiben auf Apple. Sommerzeit, die 5-Uhr-Grenze,
unvollständige Pläne und das Beibehalten bestätigter Snapshots bleiben erhalten.

Die ViewModels verwenden Coroutines `StateFlow`, benötigen aber keine
Compose-Oberfläche oder zusätzliche Swift-Interop-Bibliothek. Android kann
`state` sammeln. Der Apple-Adapter liest `current` und registriert einen synchronen
Observer; die Registrierung liefert keinen zusätzlichen Initialwert. Der Besitzer
beendet das Abonnement in `deinit`. Beobachterabmeldung ist auch außerhalb des
UI-Threads sicher. Alle Mutationen und Rückrufe erfolgen auf dem besitzenden
UI-Thread; die Transport- und Plattformadapter führen I/O und asynchrone Tasks aus und melden deren
Ergebnisse mit einer Generation zurück.

Die Cache-Wiederherstellung läuft unverändert synchron vor der ersten Darstellung.
Dafür werden weder Flow-Collector noch ein neuer Coroutine-Scope, Main-Thread-Hop
oder eine weitere Modellkonvertierung gestartet. Native Kontext-IDs verknüpfen
optionale Apple-Dienste mit einem gemeinsamen Snapshot; Programmobjekte werden
weiter direkt verwendet. Sheets, Navigation, Animationen, native Anzeigepräferenzen
und Systemberechtigungen bleiben in SwiftUI beziehungsweise den Apple-Adaptern.

## Quellen und Programmaufbereitung

Die fünf Rudolstadt-Endpunkte werden parallel durch `RemoteAPI` über Ktor geladen.
Ktor verwendet Darwin/NSURLSession auf Apple, die Android-/HttpURLConnection-Engine
auf Android und OkHttp auf JVM. Die Android-Engine erhält das bestehende compileSdk 36;
die aktuelle OkHttp-Android-Abhängigkeit würde SDK 37 und einen Toolchain-Umbau verlangen.
Status- und strikte UTF-8-Prüfung sowie Parsing bleiben in derselben Kotlin-Aufrufkette.
Swift erhält direkt `RudolstadtPayload`, News-Modelle oder die ausgewählte Musikvorschau;
es gibt keinen Rückweg der HTTP-Rohdaten über Swift zum Kotlin-Parser.
Kotlin übernimmt die Prüfung stabiler
IDs und das Zählen verworfener oder mehrdeutiger Datensätze. `RudolstadtPayload`
behält den geparsten JSON-Baum. Der native Adapter decodiert keine zweite
API-Modellhierarchie und codiert keine Swift-Modelle für Kotlin zurück. Wiederholtes
Lesen und Schreiben des Rohdaten-Caches erhöht die Verlustzählung nicht.

`ProgramExtras` und die Genre-Taxonomie werden ebenfalls gemeinsam eingelesen.
Der Rohdaten-Cache behält seine Schlüssel und ursprüngliche Download-Zeit;
Prüfsummen verwenden beim Schreiben exakt dieselben Quellbytes. Der abgeleitete
Cache bleibt normalisiert und wird bei einem neuen Build aus den vorhandenen
Rohdaten neu erzeugt. Seine Wiederherstellung benötigt kein API-Parsing.

`ProgramPreparation` erzeugt Tageszuordnungen, Dauern, Musiklinks, Gruppen,
Tag-Regeln, Eintrittskategorien, zusätzliche Orte und Karten-Zuordnungen. Auch die
Anreicherung durch native Feature-Provider läuft als typisierte Stapeloperation im
gemeinsamen Kern. Dabei werden Objekte ersetzt und Veranstaltungsreferenzen mit
den neuen Katalogobjekten verknüpft; bereits vorhandene Programme bleiben intakt.
Die native Schicht ergänzt Herkunft und Systemdienste. PDFKit-Prüfung, Dateizugriff,
native URL-Auswertung sowie Lokalisierung von Systemtexten bleiben auf Apple.

## Datumsberechnung auf dem Startpfad

Die Zeitplanfilter arbeiten direkt mit `ProgramOccurrence` und dessen IDs. Sie
bauen keine `ProgramEvent`-Planungsmetadaten auf: Tag und Startminute sind für die
Filterentscheidung unerheblich. Die eigentliche Planung berechnet diese Werte
weiterhin im gemeinsamen Kern.

IANA-Zeitzonenregeln werden pro Prozess und Kennung wiederverwendet. Auf
Kotlin/Native lädt `TimeZone.of` die Regeln aus dem Dateisystem; ein erneutes
Auflösen pro Veranstaltung und Datumsfeld blockierte die erste Darstellung.
Der Cache veröffentlicht unveränderte Maps atomar, damit gleichzeitige
Berechnungen sichere Zugriffe erhalten. Gespeichert wird die vollständige
Regelmenge, kein fester UTC-Offset; Sommer-/Winterzeit bleibt korrekt.

## Ressourcen und Prüfung

Festivaldaten haben genau eine Quelldatei unter `shared/src/commonMain/resources`.
Xcode referenziert diese Dateien; Android verpackt sie als Java-Ressourcen in der `classes.jar` des AAR.
Sie sind dort über den ClassLoader zugänglich; eine zweite Kopie für den
AssetManager ist nicht notwendig. Die
AAR-Prüfung vergleicht jede enthaltene Ressource byteweise mit der Quelle.

CI prüft gemeinsame Tests auf JVM und Kotlin/Native, Android-Kompilierung und
Ressourcen sowie die Swift-Anbindung. Vertragstests umfassen fehlerhafte Quellen,
64-Bit-IDs, Abbruch, konkurrierende Aktualisierung, Cache-Grenzen und den Erhalt
bestätigter Daten. Versionskatalog, Gradle-Wrapper, JDK-17-Toolchain, ktfmt und
separate Python-Anforderungsdateien beschreiben die verwendeten Werkzeuge.

Ktor ist im Versionskatalog festgelegt und verbindet HTTP-Abruf und Parsing im
gemeinsamen Repository. Swift erhält typisierte Kotlin-Modelle. Ein Abbruch-Token
pro Aufruf beendet bei Swift-Task-Abbruch die Kotlin-Coroutine und ihre parallelen
Teilanfragen; zusätzliche Request-Klassen und ein dauerhafter Coroutine-Scope
sind nicht erforderlich. Injizierte Testtransporte nutzen dasselbe Repository.

Der synchrone Apple-Cache verwendet weiterhin Foundation für Dateien, atomaren
Ersatz und PropertyLists sowie CryptoKit für Prüfsummen. Dateinamen, Rohdaten und
der abgeleitete `program-v2.plist`-Cache bleiben kompatibel. Prüfsumme und
Fallback-Parsing verwenden dieselben einmal eingelesenen Daten. Der Startpfad
erzeugt weder einen HTTP-Client noch einen Coroutine-Scope. Cache-Gültigkeit,
Fallback-Regeln, Serialisierung der Rohdaten und Aktualisierungsschutz bleiben
im gemeinsamen Kern. Die direkte Okio-Cache-Integration wurde entfernt: Bei
weiterhin nativem PropertyList-Format rechtfertigt sie die zusätzliche Apple-Brücke
nicht. Eine spätere gemeinsame Datenbank sollte diese Grenze erneut bewerten.

## Zeitmessungen

Weitere Startzeitmessungen sind auf Benutzerwunsch ausgesetzt. Der vorhandene
`cachedStartupRestorationBenchmark` läuft nur bei explizit gesetztem
`RUDOLSTADT_RUN_STARTUP_BENCHMARKS=1`; normale funktionale Testläufe lassen ihn aus.
Die synchrone Wiederherstellung des vorbereiteten Caches vor der ersten
Darstellung bleibt erhalten. Aus Funktionstests wird keine Kaltstartzeit abgeleitet.
