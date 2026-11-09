# Firebase: Profilabgleich und Freunde einrichten

Die Apps synchronisieren das aktuelle eigene Rudolstadt-Profil einschließlich privater
Notizen über dasselbe Firebase-Konto auf iOS und Android. Freunde teilen automatisch Markierungen und Bewertungen; Notizen bleiben privat. Die gemeinsame Logik liegt in Multiplatform, die SDK-Anbindung nativ.

CloudKit ist entfernt. Ausschließlich vorhandene lokale Altdaten werden übernommen;
Daten und Freigaben in CloudKit bleiben unangetastet und werden ignoriert. Vor dem
Upload entsteht ein lokales Originalbackup. Kontowechsel kopiert keine privaten Daten
in ein anderes Konto. Kontolöschung erhält das eigene Profil lokal und entfernt
die Firebase-Daten. App Check und umfassende Missbrauchsgrenzen bleiben
Release-Arbeit. Dies ist ein Entwicklungsstand.

## Festivalübergreifende Freundschaften

Freundschaften gelten ab Protokollversion 2 über alle Festivals und Jahre.
Die Oberflächen teilen immer Konzertmarkierungen und Bewertungen mit Symbolen;
Notizen bleiben privat. Name und Farbe sind zur Erkennung sichtbar. Es gibt keine
Freigabeschalter, Bearbeitungsdialoge oder Auswahl je Festival.

Die feste Vorgabe liegt als `FriendSharing.defaultPermissions` in Multiplatform.
Einladen und Annehmen verwenden `{ savedEvents: true, ratings: true, notes: false }`.
Der Controller abonniert keine Freundesnotizen, auch bei älteren Berechtigungen.
Bestehende Entwicklungs-Freundschaften und Einladungen werden auf diese Vorgabe
gesetzt. Der flexible Backendvertrag bleibt für spätere Erweiterungen bestehen.

Die Daten liegen getrennt:

| Pfad | Zweck / Zugriff |
| --- | --- |
| `friendIdentities/{uid}` | Globaler Name und OKHSL-Hue; nur Eigentümer und Freunde |
| `friendships/{uid}/friends/{other}` | Globale Verbindung mit `sharing` und gespiegeltem `receiving`; nur eigene Liste lesbar |
| `friendProfileEditions/{edition}/profiles/{uid}/categories/savedEvents` | Nur freigegebene Konzertmerker |
| `friendProfileEditions/{edition}/profiles/{uid}/categories/ratings` | Nur freigegebene Bewertungen/Symbole |
| `users/{uid}/profileEditions/{edition}/records` mit Filter `value.kind == "note"` | Im aktuellen App-Modell nur Eigentümer; Notizfreigabe im Backend weiterhin technisch vorhanden |
| `users/{uid}/profileEditions/{edition}/noteVersions` | Ausschließlich Eigentümer |
| `friendInvitesV2/{hash}` | Globale einmalige Einladung mit der festen App-Vorgabe; kein direkter Clientzugriff |

Die Regeln setzen die Auswahl durch. Ein ausgeblendetes UI-Feld ist kein
Zugriffsschutz. Notizen werden nicht in Sammeldokumente kopiert: die bestehende
Datensatzstruktur erhält auch große Texte und mehrere Notizen. Ein Freund kann
weder die ungefilterte private Datensatzliste noch den Verlauf lesen.

`FriendsController` in Multiplatform steuert Identität, die feste Vorgabe beim
Einladen/Annehmen, erlaubte Markierungs-/Bewertungslistener und Widerruf. Neue
Geräte publizieren erst nach Zusammenführung ihrer eigenen Replik. Globale
Verbindungen werden beim Anmelden geladen, auch ohne Profil der aktuellen Ausgabe.
Die acht Functions sind `setFriendIdentity`, `publishFriendProfile`,
`createFriendInvite`, `previewFriendInvite`, `acceptFriendInvite`,
`updateFriendSharing`, `friendConnectionStatus` und `removeFriend`. Alle verlangen
`protocol: 2` und die zur Anmeldung passende `owner`-UID. Alte `friendEditions`-
Pfade bleiben gesperrt; die Kontolöschung bereinigt beide Datenmodelle.

Details: [ADR 0003](adr/0003-global-friendships.md). Manuelle Tests und eine
Veröffentlichung der geänderten Website wurden nicht automatisch durchgeführt.

Früherer Teststand vom 5. November 2026 für den weiterhin vorhandenen Backendvertrag: 56 gezielte
Multiplatform-Tests, neun Backend-Unit-Tests und elf Auth-/Functions-/Firestore-
Integrationstests bestehen. Android-Debug-APK, gemeinsame iOS-Kompilierung und native
iOS-Anbindung erfolgreich; zwei gezielte iOS-Persistenztests bestehen. Im echten
Entwicklungsprojekt wurden zwei synthetische Konten über zwei unterschiedliche
Festivals verbunden. Merker-/Bewertungsgrenzen, explizite aktuelle Notizen bei
gesperrtem Verlauf, Widerruf und Beenden wurden mit tatsächlichen Firestore-
Zugriffen geprüft. Beide Testkonten wurden anschließend samt Daten gelöscht;
ihre technischen Löschsperren laufen über die reguläre Bereinigung aus.

## 1. Firebase-Projekt

### Gespeicherte Testnutzer

Aus dem Projektstamm legt dieses Entwicklungswerkzeug neun echte, klar markierte
Testkonten ausschließlich in `festival-friends-dev` an, darunter das Demokonto
**Alex mit acht bereits verbundenen Freunden**:

```sh
node firebase/functions/scripts/seed-test-users.mjs
```

Voraussetzung sind die bereits installierten `firebase/functions`-Abhängigkeiten
und die lokale Android-SDK-Konfiguration dieses Entwicklungsprojekts. Verwendet
werden die normalen Anmelde-, Sync- und Freundes-APIs, keine Admin-Schreibabkürzung.
Ein erneuter Aufruf erzeugt keine weiteren Konten und überschreibt keine bereits
fertig eingerichteten Profile. Ein unterbrochener Lauf setzt den gespeicherten
Zwischenstand fort.

| Testkonto | Konzertmerker | Bewertungen | Notizen | Freigabe an Freunde |
| --- | ---: | ---: | ---: | --- |
| Test · Anna | 8 | 10 | 2 | Markierungen und Bewertungen; Notizen privat |
| Test · Ben | 10 | 8 | 3 | Markierungen und Bewertungen; Notizen privat |
| Test · Clara | 9 | 9 | 2 | Markierungen und Bewertungen; Notizen privat |
| Test · David | 12 | 14 | 2 | Markierungen und Bewertungen; Notizen privat |
| Test · Emilia | 10 | 12 | 2 | Markierungen und Bewertungen; Notizen privat |
| Test · Fatima | 14 | 13 | 3 | Markierungen und Bewertungen; Notizen privat |
| Test · Jonas | 12 | 10 | 2 | Markierungen und Bewertungen; Notizen privat |
| Test · Mila | 8 | 10 | 2 | Markierungen und Bewertungen; Notizen privat |
| Demo · Alex | 16 | 20 | 4 | Markierungen und Bewertungen; Notizen privat |

Alex ist mit den acht anderen Konten verbunden; Anna, Ben und Clara sind zusätzlich
untereinander befreundet. Die gültigen Künstler-/Konzert-IDs stammen aus dem
gebündelten Rudolstadt-Programm 2026. Die ursprünglichen drei Profile bleiben bei
einer Erweiterung unverändert. Gemeinsame Favoriten, gegensätzliche Bewertungen und
zusätzliche Konzerttipps verteilen sich über eine größere Künstlerauswahl, sodass
Freundesempfehlungen nicht bereits vollständig durch die eigenen Merker und
Bewertungen ausgeschlossen werden. Alle Konten teilen Markierungen und Bewertungen. Die als Demo-/Testnotizen
gekennzeichneten Notizen bleiben privat.

Für einen Festivalbesuch mit mehreren Freunden **`firebase/.local/festival-demo.txt`**
öffnen und Alex über den dortigen Schlüssel anmelden. Es müssen keine acht
Einladungen angenommen werden. Der Zugang ist ein normales Firebase-Konto;
die App benötigt keinen besonderen Demo-Modus. Das eigene vorherige Konto kann
anschließend wieder angemeldet werden. Die Datei beschreibt auch die vorbereiteten
Freigaben und gemeinsamen Konzertmerker.

`firebase/.local/test-users.txt` enthält Zugangsschlüssel und neue Einladungslinks.
Links lassen sich unter Freunde einfügen, ohne das eigene Konto zu wechseln.
Schlüssel öffnen die Testkonten über die vorhandene Schlüsselanmeldung. Die
Zugangsdaten und der wiederaufnehmbare Zustand in `test-users.json` sind von Git
ausgeschlossen und nur für den lokalen Benutzer lesbar. Diese Dateien nicht
veröffentlichen. Einladungen sind sieben Tage und einmalig gültig; neue Links
werden bei Bedarf erzeugt mit:

```sh
node firebase/functions/scripts/seed-test-users.mjs --refresh-invites
```

Das Erneuern verändert keine Profildaten oder Freundschaftsfreigaben; eine neue
Einladung ersetzt jeweils den vorherigen Link. Testkonten können über die normale
Kontolöschung in der App vollständig aus Firebase entfernt werden.

Zunächst ein **Entwicklungsprojekt** anlegen; Produktion später getrennt konfigurieren.
Das eingerichtete Entwicklungsprojekt heißt `festival-friends-dev`; der lokale
CLI-Alias `dev` und das Hosting-Ziel `auth` verweisen ausschließlich darauf.
Analytics ist nicht erforderlich. Für Cloud Functions ist der **Blaze-Tarif** mit
Abrechnungskonto nötig. Kostenwarnungen konfigurieren; sie sind keine Ausgabensperre.

- Firestore **Standard Edition / Native Mode**, Datenbank `(default)`, Standort
  **Frankfurt `europe-west3`** erstellen. Kein offener Testmodus: die Regeln liegen
  in `firebase/firestore.rules`.
- iOS-App registrieren: Bundle-ID `de.leongeorgi.RudolstadtForiOS`.
  In den App-Einstellungen außerdem Team-ID `RJYK9W2A39` und bei Bedarf
  App-Store-ID `1629927812` eintragen, damit Hosting die App-Verknüpfung erzeugen kann.
  `GoogleService-Info.plist` nach `iosApp/iOS/GoogleService-Info.plist` legen.
  Die Buildphase kopiert sie optional ins iOS-Bundle. Nicht selbst zusätzlich
  als Xcode-Ressource aufnehmen; die lokale Datei ist von Git ausgeschlossen.
- Android-App registrieren: Paket `de.leongeorgi.rudolstadt.android`.
  `google-services.json` nach `androidApp/google-services.json` legen. Das
  Google-Services-Plugin wird nur mit dieser Datei angewendet.
- Android-SHA-1 und SHA-256 der tatsächlich verwendeten Debug-/Release-Zertifikate
  in den Projekteinstellungen hinzufügen. Bei Play App Signing auch den
  App-Signing-Fingerabdruck registrieren.
- Authentication: **E-Mail/Passwort** aktivieren und dort zusätzlich
  **E-Mail-Link (passwortlose Anmeldung)** einschalten. Die Apps bieten kein Passwortfeld.
- Authentication → autorisierte Domains: `festival.leongeorgi.de` und
  `auth.festival.leongeorgi.de` aufnehmen.
- Firebase Hosting aktivieren und `auth.festival.leongeorgi.de` als benutzerdefinierte
  Domain verbinden. Die verlangten DNS-Einträge beim Domainanbieter setzen.
  Diese Subdomain gehört zu Firebase Hosting, die bestehende Festival-Website bleibt bestehen.
  Die kleine Auth-Website liegt in `firebase/auth-hosting`; sie verwendet kein Web-SDK.
  Aus `firebase` lässt sie sich separat bereitstellen:

  ```sh
  ./functions/node_modules/.bin/firebase deploy --project dev --only hosting:auth
  ```

  Hosting erzeugt die App-Zuordnungsdateien über `appAssociation: AUTO` aus den
  Firebase-App-Einstellungen. iOS-Team-ID und Android-Zertifikate deshalb vor dem
  Gerätetest prüfen. Die reservierten `/__/auth/`-Pfade stellt Firebase selbst bereit.
- Für E-Mail-Links die App-Verknüpfung der Hosting-Domain prüfen:
  iOS Associated Domains enthält `applinks:auth.festival.leongeorgi.de`;
  Android hat einen Intent-Filter für `/__/auth/links`. Hosting muss die AASA-
  und Digital-Asset-Links-Dateien für die registrierten Apps korrekt ausliefern.
  Keine Firebase Dynamic Links verwenden.

Offizielle Anleitungen: [iOS E-Mail-Links](https://firebase.google.com/docs/auth/ios/email-link-auth),
[Android E-Mail-Links](https://firebase.google.com/docs/auth/android/email-link-auth).

## Google-Anmeldung

Die Apps enthalten Google als weitere Anmeldeoption. Android verwendet Credential
Manager 1.6.0 mit dem expliziten Google-Anmeldebutton (`GetSignInWithGoogleOption`)
und Google ID 1.2.1. iOS verwendet GoogleSignIn / GoogleSignInSwift 10.1.0 per SPM.
Tokens und Provider-UI bleiben nativ; der gemeinsame `FriendsController` besitzt
Busy-Zustand, Abbruchverhalten und verständliche Authentifizierungsfehler. Die
Google-Anmeldung aktiviert keine Freundesfreigabe. Das Verknüpfen von Anmeldearten
ist ausdrücklich keine App-Funktion (Entscheidung vom 5. November 2026).

Einmal im Entwicklungsprojekt unter Authentication → Anmeldemethode → Google den
Anbieter aktivieren, eine Support-E-Mail auswählen und speichern. Anschließend
beide SDK-Konfigurationen erneuern. Der vorhandene Android-Debug-SHA-1 und SHA-256
wurden am 4. November 2026 gegen Firebase geprüft und stimmen überein. Für spätere
Release-/Play-Zertifikate müssen deren Fingerabdrücke zusätzlich registriert werden.

Die Dateien können aus `firebase` auch direkt mit der angemeldeten CLI abgerufen
werden (zuerst in neue temporäre Dateien schreiben, Projekt- und App-IDs prüfen und
anschließend die vorhandenen, von Git ignorierten Dateien ersetzen):

```sh
./functions/node_modules/.bin/firebase apps:sdkconfig IOS 1:1009155419788:ios:5a01bb1a7b91978d4615a9 --project dev --out /tmp/GoogleService-Info-new.plist
./functions/node_modules/.bin/firebase apps:sdkconfig ANDROID 1:1009155419788:android:bcc5e231ea70338c4615a9 --project dev --out /tmp/google-services-new.json
```

iOS benötigt `CLIENT_ID` und `REVERSED_CLIENT_ID`; Android benötigt den Web-OAuth-
Client (Typ 3) und den zum Signierungszertifikat passenden Android-Client (Typ 1).
Der Google-Services-Gradle-Schritt erzeugt daraus `default_web_client_id`.
`scripts/ios/prepare-firebase.sh` erzeugt die iOS-Info.plist im Derived-Ordner und
registriert das Rücksprungschema aus `REVERSED_CLIENT_ID`, ohne Quelldateien beim
Build zu verändern. SwiftUI reicht eingehende Google-URLs zuerst an das Google-SDK.
Ohne OAuth-Konfiguration bleiben Builds sowie Apple- und E-Mail-Anmeldung nutzbar;
der Google-Button meldet die fehlende Einrichtung. Es sind keine zusätzlichen
Apple-Developer-Capabilities und kein Functions-Deploy erforderlich.

Offizielle Einrichtung: [Firebase iOS](https://firebase.google.com/docs/auth/ios/google-signin),
[Firebase Android](https://firebase.google.com/docs/auth/android/google-signin).
Das Android-Buttonlogo stammt unverändert aus
[Googles Anmeldeassets](https://developers.google.com/static/identity/images/g-logo.png).

Google-Ergänzung am 4. November 2026 geprüft: Android-Debug-Build und abschließende
Kotlin-Kompilierung erfolgreich; 33 gezielte gemeinsame Tests einschließlich
Auth-Konfiguration, Kontokonflikten, Abbruch und verspäteten Ergebnissen erfolgreich.
Die iOS-Anbindung kompiliert mit den neuen SPM-Produkten; zwei gezielte native
Persistenztests bestehen. Die Info.plist-Erzeugung wurde für fehlende SDK-Dateien,
E-Mail-Konfiguration und Google-Konfiguration geprüft. Der Live-Google-Login wurde
nicht ausgeführt. Der Google-Anbieter wurde anschließend aktiviert und beide lokalen SDK-Dateien
über die Firebase-CLI erneuert. Projekt-/App-Zuordnung, iOS-Client und Rücksprungschema
sowie Android-Web-Client und Debug-Zertifikat wurden geprüft. Die Konfigurationsdateien
bleiben von Git ausgeschlossen. Mit den erneuerten Dateien wurde das Android-Debug-APK
erfolgreich erstellt; der iOS-Testlauf mit zwei gezielten Tests besteht ebenfalls.
Der erzeugte Android-Web-Client und die tatsächlich im iOS-App-Bundle enthaltene
Client-ID samt Rücksprungschema wurden mit den heruntergeladenen Dateien abgeglichen.

## Anmelde- und Kontooberflächen

Nicht angemeldete Nutzer sehen beim Öffnen von Konto, Freunden und geschützten
Unterseiten direkt den zentralen Login-Screen mit Apple, Google, E-Mail und
anonymem Konto mit Zugangsschlüssel. Es gibt keine vorgelagerten Konto- oder
Freundeseiten mit zusätzlichen Anmelde-Buttons. Nach der Anmeldung erscheint
der ursprünglich geöffnete Bereich; bei einem neuen anonymen Konto bleibt
zunächst die einmalige Schlüsselanzeige sichtbar. Abmelden führt wieder direkt
zum Login. Allgemeine Einstellungen zeigen ohne Sitzung keine eigene
Synchronisierungskarte mit Anmeldeaufforderung.

**Konto** zeigt nach der Anmeldung Profil, Anmeldestatus, Synchronisierung und
Freigabe an Freunde.
E-Mail-Adresse und vorhandener Schlüssel werden auf separaten Unterseiten
eingegeben; empfangene E-Mail-Links öffnen die E-Mail-Anmeldung. Zurück führt
zur vorherigen Ansicht, ohne eine weitere Anmeldeaufforderung zu öffnen.

Anonyme Konten zeigen **Anonymes Konto** anstelle einer E-Mail-Adresse. Der neu
erzeugte Schlüssel erscheint einmalig mit QR-Code, expliziter Kopieraktion und
Sicherungshinweis. Schlüsselverwaltung und Synchronisierungsdetails sind eigene
Unterseiten. Abmelden, Kontolöschung und die gesonderte Zustimmung zur
Freundesfreigabe verwenden weiterhin die gemeinsamen Multiplatform-Controller.
Es gibt keine Funktion zum Verknüpfen von Anmeldearten.

Die Referenzen liegen in `design/Rudolstadt.sketch` auf **Konto & Sync · Konzepte**,
einschließlich der fünf Unterseiten für beide Plattformen. iOS verwendet
verknüpfte Komponenten des Apple iOS 27 UI Kit. Profil- und Kontostatus sind
illustrative Beispiele; der Design-QR-Code enthält keinen Zugangsschlüssel.
Die Sketch-Frames wurden visuell geprüft, gespeichert und erneut geöffnet.
Der iOS-Abgleich vom 5. November 2026 verwendet einen iPhone-17-Pro-Simulator
mit iOS 27.0, deutscher Sprache und heller Darstellung. Login, E-Mail- und
Schlüsselanmeldung, anonymes Konto, Schlüsselverwaltung, einmalige Schlüsselanzeige
und Synchronisierungsdetails sind mit nativen Aufnahmen verglichen. Bericht,
Originalreferenzen und unveränderte Kanalvergleiche liegen unter
`design/implementation-account-ios-2026-11-05/`. Android, Dark Mode und große
Schrift sind damit noch nicht visuell abgenommen. Eine vollständige Pixelgleichheit
wird wegen der dokumentierten Unterschiede nicht behauptet.

Geprüft: Android `compileDebugKotlin`, isolierte Swift-Typprüfung der geänderten
Ansichten gegen vorhandene App-Module, Ressourcen und Xcode-Projektdatei sowie
20 gemeinsame Tests für Schlüsselanmeldung und Kontolöschung. Zusätzlich bestehen
ein vollständiger signierter iOS-Simulatorbuild und die beiden gezielten
`AccountLayoutTests` für abgemeldete Oberflächen und den anonymen Kontoablauf
einschließlich Kontolöschung. Die hierfür erzeugten DEV-Konten wurden wieder
gelöscht; die Schlüsselaufnahmen werden erst nach erfolgreicher Löschung angehängt.
Apple-/Google-OAuth und der Versand von E-Mail-Links waren nicht Teil dieser
Layoutprüfung.

Der iOS-Google-Button verwendet anschließend eine eigene flache Kapsel mit
50 pt Mindesthöhe, zentrierter Beschriftung und dem offiziellen aktuellen
Verlaufslogo. Die Anmeldung ruft denselben nativen Google-Adapter auf.
Google Sans Medium ist als lateinischer 68-KB-Ausschnitt lokal gebündelt;
Originalschrift und OFL stammen aus `google/fonts/ofl/googlesans`.
Das unveränderte Logo stammt aus Googles Branding-Richtlinien
(`https://developers.google.com/identity/branding-guidelines`). Licht-/Dunkelfarben
und Kontur folgen deren Vorgaben. Referenz und neue Simulatoraufnahme liegen in
`design/google-button-2026-11-05/`; der frühere Gesamtabgleich bleibt erhalten.

## Anmeldung mit geheimem Schlüssel

Auf iOS und Android lässt sich ein Konto ohne E-Mail-Adresse erstellen oder durch
Eingeben beziehungsweise Scannen eines vorhandenen Schlüssels öffnen. Dies sind
eigenständige Schlüssel-Konten. Apple-, Google- und E-Mail-Konten können weder einen
Schlüssel erstellen noch per Schlüssel geöffnet werden. Auch zuvor ergänzte
Zusatzschlüssel werden serverseitig abgelehnt; deren Konten und Profildaten bleiben
erhalten. Die Freundesfreigabe verlangt weiterhin ihre eigene Zustimmung.

Der Schlüssel wird aus 160 kryptographisch zufälligen Bits erzeugt und als
`FF1-` mit acht Vierergruppen dargestellt. Er erscheint einmalig mit Kopierbutton
und QR-Code und gehört in einen Passwortmanager. Beim Verlassen des Bildschirms
oder Wechsel in den Hintergrund wird die Anzeige verborgen. Der Schlüssel steht
weder in gespeicherten UI-Zuständen noch in Profiljournalen oder Logs. Kopieren
ist ausdrücklich; iOS verwendet eine lokale Zwischenablage mit zwei Minuten
Ablaufzeit, Android markiert den Inhalt als vertraulich.

`AccountKeyController` in Multiplatform steuert Normalisierung, Kontoerzeugung,
Anmeldung, wiederholbare Aufträge, Kontowechsel und sichtbare Fehler.
`AccountActionGate` wird mit `FriendsController` geteilt und serialisiert die
Anmeldeaktionen. Native Adapter liefern `SecRandomCopyBytes` beziehungsweise
`SecureRandom` und reichen das Custom Token an das jeweilige Firebase-SDK weiter.
Der Schlüssel wird nur über TLS als Callable-Payload übertragen, nie als URL.

Die Kontotyp-Prüfung liegt in Multiplatform (`isKeyAccount`) und wird auf beiden
Oberflächen verwendet. Der Server prüft zusätzlich die Registrierung im reservierten
`key_`-Namensraum, den Eigentümerdatensatz und die tatsächlichen Firebase-Auth-
Anbieter/E-Mail-/Telefonfelder. Der aktuelle Token-Anbieter `custom` allein genügt
nicht, weil ein altes Zusatzschlüssel-Login ebenfalls ein Custom Token verwendet.
Neue Eigentümerdatensätze tragen `kind: standalone`; echte frühere Schlüssel-Konten
bleiben kompatibel. Alle vier Schlüssel-Endpunkte verhindern den Zugang zu
Anbieter-Konten. Ein noch angemeldetes Schlüssel-Konto kann seinen Schlüssel
ersetzen; die UID und das Profil bleiben dabei erhalten.


Die vier zusätzlichen Functions gehören zur Codebase `friends` in `europe-west3`:

- `createKeyAccount`: neues Konto, idempotent bei Wiederholung desselben Schlüssels.
- `signInWithAccountKey`: vorhandenen Schlüssel gegen ein Custom Token tauschen.
- `accountKeyStatus`: eigenen Schlüsselstatus bei Bedarf lesen.
- `replaceAccountKey`: vorhandenen Schlüssel eines eigenständigen Schlüssel-Kontos ersetzen.

Private Serverdokumente `accountKeySecrets/{sha256}` und `accountKeyOwners/{uid}`
enthalten nur Hash, zufällige unabhängige UID und Versionsmetadaten. Die vorhandenen
Firestore-Regeln verbieten jeden direkten Clientzugriff. Transaktionen prüfen
Version und Eigentümer; ein veralteter Auftrag kann keinen neueren Schlüssel
überschreiben. Der vorherige Schlüssel erlaubt nach Ersetzen keine neuen
Anmeldungen. Bereits angemeldete Geräte bleiben angemeldet. Ohne Schlüssel, eine
noch angemeldetes Gerät gibt es keine
Wiederherstellung. Ein angemeldetes Gerät kann einen neuen Schlüssel erzeugen.

Anfragelimits: Kontoerzeugung 300/Stunde/IP, Anmeldung 1800/Stunde/IP,
Schlüsselwechsel 20/Stunde/UID. `accountKeyLimits` enthält feste gehashte
Bucket-IDs mit Zähler und Beginn des Stundenfensters, keine rohe IP oder Schlüssel.
App Check und umfassende Missbrauchs-/Kostenbegrenzungen bleiben Release-Arbeit.

Für Custom Authentication muss kein zusätzlicher Anbieter in der Firebase-Konsole
aktiviert werden. Das Functions-Dienstkonto benötigt die IAM Credentials API und
die Berechtigung zum Signieren eigener Tokens. Im Entwicklungsprojekt wurde die
API geprüft und dem Konto `1009155419788-compute@developer.gserviceaccount.com`
die Rolle `roles/iam.serviceAccountTokenCreator` **nur auf diesem Dienstkonto**
gegeben. Es wurde kein privater Dienstkontoschlüssel erzeugt. Für ein neues Projekt
die entsprechende Laufzeitidentität verwenden; Anleitung:
[Firebase Custom Tokens](https://firebase.google.com/docs/auth/admin/create-custom-tokens).

Gezielter Deploy aus `firebase`:

```sh
./functions/node_modules/.bin/firebase deploy --project dev --only functions:friends:createKeyAccount,functions:friends:signInWithAccountKey,functions:friends:accountKeyStatus,functions:friends:replaceAccountKey
```

Am 5. November 2026 ausschließlich diese vier Funktionen nach
`festival-friends-dev` bereitgestellt. Geprüft: 42 gezielte gemeinsame Tests,
acht Backend-Unit-Tests, drei bisherige sowie drei Schlüssel-Integrationstests
mit echten lokalen Auth-/Functions-/Firestore-Emulatoren. Die letzten drei prüfen
auch den Erhalt privater Notizen und Freundschaften, Zugriffsschutz, Versionskonflikte
und Anfragelimits. Android-Debug-APK und iOS-Anbindung kompilieren; zwei gezielte
native Persistenztests bestehen. Im echten Entwicklungsprojekt wurden mit einem
synthetischen Konto Erstellung, Token-Signierung, Anmeldung über einen zweiten
Client und Schlüsselwechsel geprüft. Das Testkonto und seine Credential-Dokumente
wurden anschließend entfernt. Manuelle und visuelle Geräteprüfungen wurden nicht
ausgeführt; die Datenschutzseite wurde nur im Repository ergänzt, nicht veröffentlicht.

## Konto löschen, Profil lokal behalten

Unter Freunde steht bei angemeldetem Konto **Konto endgültig löschen**. Eine
Bestätigung nennt den Umfang und den lokalen Datenerhalt. Apple-Konten bestätigen
zunächst dieselbe Apple-Identität erneut; iOS widerruft den Authorization Code,
Android den Apple Access Token mit dem jeweiligen Firebase-SDK. Hierfür bleibt die
bestehende Apple-Anbieterkonfiguration erforderlich. Kein neuer Anmeldeanbieter ist nötig.
Offizielle Anleitung: [iOS](https://firebase.google.com/docs/auth/ios/apple#token_revocation),
[Android](https://firebase.google.com/docs/auth/android/apple#token_revocation).

`AccountDeletionController` in Multiplatform speichert zuerst über
`OwnProfileController` einen wiederaufnehmbaren Auftrag im lokalen Journal und
stoppt den eigenen Sync. Erst nach erfolgreichem Speichern wird der Server
aufgerufen. Nach Bestätigung bleiben das aktuelle Profil, private Notizen und noch
nicht hochgeladene Änderungen als lokale Replik erhalten, auch nach einem Neustart.
Der alte Konto-Eintrag wird abgelöst und seine UID lokal vom Sync ausgeschlossen.
Ein später bewusst neu angemeldetes erstes Konto kann die lokalen Daten übernehmen.
Andere lokale Konten und das Originalbackup werden nicht entfernt. Während eines
offenen Löschauftrags sind andere Kontoaktionen gesperrt; **Löschung fortsetzen**
setzt ihn bei Netz- oder Speicherproblemen fort. Beim App-Start wird er ebenfalls
wiederaufgenommen. Der zufällige 160-Bit-Löschbeleg erlaubt ausschließlich das
Fortsetzen des schon autorisierten Auftrags, keinen Zugriff auf Profil oder Konto.

Vier neue Functions:

- `deleteAccount`: autorisierten Auftrag anlegen beziehungsweise mit Beleg fortsetzen;
  anschließend auf die Löschung von Firestore-Daten und Firebase Auth warten.
- `accountDeletionStatus`: Löschstatus einer bereits bekannten UID bestätigen, damit
  weitere Geräte bei Zugriffsverlust ihren letzten lokalen Stand behalten können.
- `eraseDeletedAccount`: Firestore-Trigger mit Wiederholung bei Serverfehlern.
- `finishAccountDeletions`: alle 15 Minuten offene Aufträge wiederholen und abgelaufene
  Schutzaufträge endgültig entfernen.

Gelöscht werden `users/{uid}` einschließlich sämtlicher Unterkollektionen und
Ausgaben, private Notizversionen, alle Freigabeprofile und Mitgliedschaften,
eingehende Freundschaften in anderen Profilen, besessene oder eingelöste Einladungen,
alle zugeordneten Schlüssel und der UID-bezogene Schlüsselwechsel-Zähler sowie
der Firebase-Auth-Nutzer. Andere Konten bleiben erhalten. Der Gruppenindex für
`friends.uid` in `firebase/firestore.indexes.json` findet auch verwaiste Gegenrichtungen.
Nicht kontobezogene gemeinsame IP-Anfragelimits bleiben als technische Missbrauchszähler
bestehen; sie enthalten keine UID und keinen Schlüssel.

`accountDeletions/{uid}` sperrt Reads in den Regeln und wird innerhalb jeder
schreibenden Transaktion geprüft. So können laufende Geräte Daten nicht nachträglich
wieder anlegen. Nach dem Löschen bleibt nur dieser technische Schutzauftrag mit
gehashtem Löschbeleg, Status und Ablaufdatum bestehen. Vorher ausgestellte Custom Tokens
können noch eine Stunde gültig sein. Nach zwei Stunden löscht der nächste 15-Minuten-Lauf
den Schutzauftrag und eine gegebenenfalls mit einem alten Token neu erzeugte leere
Auth-Identität. Bei Serverausfällen bleibt die Sperre bis zum erfolgreichen Abschluss
bestehen. Der Beleg wird nie geloggt. Für Status und Wiederaufnahme nach Auth-Löschung
verwenden native Adapter einen benannten Firebase-SDK-Kontext ohne angemeldeten Nutzer;
dadurch verhindert ein inzwischen ungültiges SDK-Token nicht den Abschluss.

Für die Einrichtung werden Firestore-Regeln, Gruppenindex und **alle** Functions
dieser Codebase zusammen aktualisiert, da auch bestehende Schreibwege die Sperre
prüfen. Die CLI kann beim ersten Deploy nach der Fehlerwiederholung fragen; die
Löschoperationen sind idempotent. Cloud Scheduler und Eventarc müssen aktiviert sein;
die Firebase CLI übernimmt dies im Blaze-Entwicklungsprojekt. Beispiel aus `firebase`:

```sh
./functions/node_modules/.bin/firebase deploy --project dev --only firestore:rules,firestore:indexes,functions:friends
```

Am 5. November 2026 im Entwicklungsprojekt bereitgestellt: alle vier neuen
Löschfunktionen aktiv, die zehn bisherigen Funktionen um die Sperrprüfung ergänzt,
Regeln aktualisiert und `friends.uid`-Gruppenindex aufgebaut. Der erste Eventarc-
Triggerdeploy wurde nach Verteilung der bereits korrekt zugewiesenen Service-Agent-
Rolle erfolgreich wiederholt. Es war keine zusätzliche manuelle Einrichtung nötig.

Verifiziert: 51 gezielte gemeinsame Tests, acht Backend-Unit-Tests und acht
Emulator-Integrationstests bestehen. Darunter sind verlorene Antworten, Neustart
nach Abmeldung, Speicherfehler vor und nach dem Serverauftrag, konkurrierender
Kontowechsel, Erhalt privater Notizen, mehrere Ausgaben, fremde Konten, alte Custom
Tokens und mehr als ein Firestore-Löschbatch. Android-Debug-APK und native iOS-
Anbindung kompilieren; zwei gezielte iOS-Persistenztests bestehen. Im echten
Entwicklungsprojekt wurden mit einem synthetischen Konto die Löschung von Konto,
privater Notiz, Freigabeprofil und Schlüssel sowie Wiederaufnahme ohne Anmeldung
geprüft. Die Test-Kontodaten sind entfernt; dessen technischer Sperrauftrag läuft
über die reguläre automatische Bereinigung aus. Manuelle UI-/Apple-Dialogtests
wurden wie gewünscht ausgelassen. Die Datenschutzseite ist nur im Repo aktualisiert.

## 2. Apple Developer

Unter Certificates, Identifiers & Profiles:

1. App-ID `de.leongeorgi.RudolstadtForiOS` öffnen, **Sign in with Apple** aktivieren
   und als primäre App-ID konfigurieren. **Associated Domains** muss ebenfalls aktiv sein.
   Team-ID des Projekts: `RJYK9W2A39`.
2. Eine **Services ID** für die gemeinsame Web-/Android-Anmeldung erstellen.
   Für Entwicklung eingerichtet: `de.leongeorgi.festivalfriends.firebase.dev`.
   Sign in with Apple aktivieren und mit derselben primären App-ID verbinden.
3. Bei der Services ID als Domain `festival-friends-dev.firebaseapp.com` und als Return URL
   exakt `https://festival-friends-dev.firebaseapp.com/__/auth/handler` registrieren.
   Falls Firebase einen eigenen Auth-Handler auf einer benutzerdefinierten Domain
   verwendet, stattdessen genau die von Firebase angezeigte Redirect-URL registrieren.
4. Unter Keys einen Schlüssel mit **Sign in with Apple** erstellen, derselben
   App-ID zuordnen und die `.p8` einmalig sicher herunterladen.
5. In Firebase Authentication → Apple die Services ID, Team-ID, Key-ID und den
   privaten Schlüssel hinterlegen. **Die `.p8` gehört ausschließlich in Firebase
   beziehungsweise sichere Schlüsselverwaltung, niemals ins Repo oder App-Bundle.**
6. Signierungsprofile mit der neuen Capability aktualisieren beziehungsweise durch
   Xcode neu erzeugen lassen. Die Sign-in-with-Apple-Entitlement ist bereits eingetragen.
7. Falls Firebase E-Mails an versteckte Apple-Adressen senden soll: Apples Private
   Email Relay für den Firebase-Absender konfigurieren.

Anleitungen: [Apple mit Firebase auf iOS](https://firebase.google.com/docs/auth/ios/apple),
[Apple auf Android](https://firebase.google.com/docs/auth/android/apple).

## 3. Backend lokal testen und gezielt bereitstellen

Die Client-Abläufe liegen in `shared/.../profile/FriendsController.kt`, `AccountKeyController.kt` und `OwnProfileController.kt`. iOS und
Android enthalten nur die nativen Firebase-/Login-Adapter und die Oberflächen.
Ohne Firebase-Zugang lassen sich die gemeinsamen Abläufe mit kontrollierter
Coroutine-Zeit prüfen:

```sh
./gradlew :shared:jvmTest --tests de.leongeorgi.rudolstadt.FriendsControllerTests --tests de.leongeorgi.rudolstadt.FriendSharingTests --tests de.leongeorgi.rudolstadt.AccountKeyControllerTests --tests de.leongeorgi.rudolstadt.OwnProfileControllerTests
```

Node 22 und Java 21 verwenden. Im Verzeichnis `firebase/functions`:

```sh
npm ci
npm test
npm run test:emulator
```

Die Emulatorprüfung benutzt ausschließlich `demo-rudolstadt` mit lokalen Konten.
Sie testet echte Functions-Aufrufe und Firestore-Regeln. Für den echten Entwicklungs-
Meilenstein anschließend aus `firebase` mit einer angemeldeten Firebase CLI:

```sh
cp functions/.env.festival-friends-dev.example functions/.env.festival-friends-dev
./functions/node_modules/.bin/firebase deploy --project dev --only firestore:rules,functions:friends
```

Die optionale lokale, von Git ausgeschlossene Datei `functions/.env.festival-friends-dev`
benötigt keine Ausgabe-Whitelist mehr. Ein noch vorhandenes `FRIEND_EDITION_IDS` wird
nicht ausgewertet. Festivalinhalte verlangen weiterhin geprüfte Kennungen wie
`rudolstadt-2026`; Freundschaften und Freigaben benötigen keine Ausgabe.
Die Functions liegen in `europe-west3`; maximal drei Instanzen pro Function.
Das Backend enthält acht globale Freundes-Functions, `syncOwnProfile`, vier
Functions zur Schlüsselanmeldung und vier zur Kontolöschung (insgesamt 17).
Der bestehende `friends.uid`-Gruppenindex wird auch für die neue Kontolöschung verwendet.
Für `gcf-artifacts` in `europe-west3` ist eine Aufräumregel eingerichtet:
Function-Build-Images werden nach einem Tag gelöscht.
Bei einer Neueinrichtung lässt sie sich so setzen:

```sh
./functions/node_modules/.bin/firebase functions:artifacts:setpolicy --project dev --location europe-west3 --days 1 --force
```

Für eine spätere Veröffentlichung App Check und umfassende Missbrauchsgrenzen
vervollständigen und gegen die realen Projekte testen. Das Repo aktiviert keine
Abrechnung und führt keinen produktiven Deploy automatisch aus.

## 4. Einladungslinks

Die bestehende Website muss einmal mit den geänderten Dateien veröffentlicht werden:
`/.well-known/apple-app-site-association` erlaubt jetzt zusätzlich `/rudolstadt/friends`.
Androids vorhandene `assetlinks.json` muss zum verwendeten Signierungszertifikat passen.
Die Einladung selbst verwendet:

```text
https://festival.leongeorgi.de/rudolstadt/friends?v=2&token=<TOKEN>
```

Sieben Tage, einmal verwendbar; eine neue Einladung ersetzt die alte. Die Website
zeigt keine Profildaten und keine automatischen Einlösungen. Das manuelle Einfügen
des vollständigen Links wird nicht als eigener Bedienweg angeboten. Nutzer tippen
auf den Link oder scannen den QR-Code; verifizierte App-Links öffnen die Vorschau
direkt in der App. Die manuelle Eingabe von E-Mail-Anmeldelinks bleibt davon unabhängig.

### Native Freundesoberflächen

Die Freundesseite zeigt Empfehlungen und darunter die Freunde. Das Plus-Menü
enthält Einladung und Scanner. Der Badge öffnet ein Menü für Profilbearbeitung,
Schlüsselverwaltung bei Schlüsselkonten, Abmelden und Kontolöschung. Das Sheet
zum Erstellen oder Bearbeiten des Profils nimmt Name und Badge-Farbe gemeinsam
entgegen. Die Profilmutation erhält Merker, Bewertungen und private Notizen.
Der Sync-Button in der Toolbar startet den Abgleich. Bei einem Fehler erscheint
eine Meldung auf der Freundesseite.

iOS nutzt SwiftUI-Listen, native Menüs und Navigation sowie die vorhandenen
Künstlerkarten. Android verwendet eine Material-Expressive-App-Bar, gefüllte
Künstlerkarten, segmentierte Freundeslisten, Outlined-Textfelder und große
Aktionsbuttons. Die native Android-Menü- und App-Bar-API ist in der
[Compose-Dokumentation](https://developer.android.com/develop/ui/compose/components/menu)
und der [LargeFlexibleTopAppBar-Referenz](https://developer.android.com/reference/kotlin/androidx/compose/material3/LargeFlexibleTopAppBar.composable)
beschrieben. Beide Oberflächen verwenden weiterhin die gemeinsame Empfehlungslogik.

Ein eingehender Einladungslink öffnet nach Anmeldung und Profileinrichtung
automatisch die Vorschau. Die Freundschaft entsteht erst nach ausdrücklicher
Bestätigung. Die Vorschau liefert bisher nur den Namen, daher zeigt sie ein
neutrales Personensymbol; echte Profilfarben werden aus den verbundenen Profilen
geladen. Android nutzt den nativen Google-Code-Scanner und bietet bei einem
Startfehler einen erneuten Versuch an; iOS verwendet die Kameraansicht mit
Einstellungslink bei verweigertem Zugriff. Es gibt keine Freigabeeinstellungen.
In Freundesdetails lassen sich Merker und Bewertungen innerhalb der Seite aufklappen.

Die [Prüfung der nativen Komponenten](../design/implementation-friends-native-2026-11-05/index.html)
umfasst acht Zustände je Plattform. Sie dokumentiert SwiftUI-Formulare, native
Toolbar-Elemente und Material-Standardkomponenten einschließlich der Grenzen der
Aufnahmeserie. Die Entwicklungskonten bleiben dabei inhaltlich unverändert;
nur ihre kurzlebige Einladung wird für den QR-Zustand erneuert.

## 5. Manuelle Abnahme auf zwei Geräten

Auf iPhone und Android mit **verschiedenen** Konten anmelden und das globale
Freundesprofil einmal einrichten. Auf dem iPhone eine Einladung erstellen;
Android scannt den QR-Code oder öffnet den Link. Der Name des Einladenden und der
Hinweis auf geteilte Markierungen/Bewertungen erscheinen vor dem ausdrücklichen
Annehmen. Keine Freigabe-Auswahl wird angeboten. Auf beiden Geräten die
Freundesprofile öffnen und Markierungen/Bewertungen über mehrere Festivals prüfen.
Notizen und Notizverlauf bleiben auch beim direkten Serverzugriff gesperrt.
Danach die Freundschaft beenden: Beide verlieren weitere Serverzugriffe.
Offline vorhandene Kopien verschwinden beim nächsten Abgleich.

Beim Widerruf kann Firestore einem noch aktiven Profil-Listener bereits den Zugriff
entziehen, bevor die entfernte Mitgliedschaft in der Freundesliste ankommt. Der
gemeinsame `FriendsController` entfernt das Profil sofort und prüft bei `PERMISSION_DENIED`
über `friendConnectionStatus` die globale Verbindung und aktuelle Berechtigung.
Entfernung oder reduzierte Freigabe werden ohne Fehlermeldung übernommen; eine
unverändert erlaubte oder nicht überprüfbare Verbindung bleibt ein sichtbarer Fehler. Antworten alter Listener oder Kontositzungen werden verworfen.

Zusätzlich abgelaufene/verwendete Einladungen, eine weitere Festivalausgabe ohne neue Einladung,
Netzausfall und Kontowechsel prüfen. Einladungen bleiben während der Anmeldung
im Arbeitsspeicher erhalten; bei einem beendeten App-Prozess den ursprünglichen
Link erneut öffnen. Kontoübergreifend werden keine Freundeslisten behalten.

## 6. Eigenes Profil: Daten und lokale Übernahme

Die privaten Datensätze stehen unter
`users/{uid}/profileEditions/rudolstadt-2026/records`:

| Dokument | Inhalt |
| --- | --- |
| `profile` | Name und OKHSL-Hue (`hue`, Grad in `[0, 360)`) |
| `event:{id}` | Merker oder Löschung |
| `rating:{id}` | Bewertung und alternatives Icon oder Löschung |
| `note:{id}` | Vollständiger privater Text oder Löschung |
| `../noteVersions/{hash}` | Private Notizversionen für Konflikt-/Originalerhalt |

Jeder Datensatz besitzt `version.modifiedAt` und `version.changeID`. Eine serverseitige
Transaktion entscheidet pro Schlüssel über den Gewinner. Fehlende Dokumente löschen
keine lokalen Werte. Clients dürfen private Dokumente nur als Eigentümer lesen und
niemals direkt schreiben. `syncOwnProfile` prüft Account, Ausgabe und Felder. Die
Freundesfreigabe nutzt getrennte Kategorien unter `friendProfileEditions`. Aktuelle
Notizen werden von den Apps nicht freigegeben. Der Backendvertrag könnte explizite
Notizfreigaben weiterhin abbilden; die feste App-Vorgabe schaltet sie aus.
`noteVersions` bleibt ausschließlich dem Eigentümer zugänglich.

Beim Update liest iOS den bisherigen Jahrgangscache beziehungsweise die ursprünglichen
Jahresschlüssel, Android die bisherigen DataStore-Profile. Vor Netzwerkzugriffen entsteht
ein Journal mit Originaldaten, Queue und getrennten Kontorepliken. iOS speichert es
unter `firebase-own-profile-2026-v1` sowie den ursprünglichen nativen Cache unter
`firebase-own-profile-2026-v1-legacy-backup`. Android hält das Journal atomar zusammen
mit der kompatiblen Profilprojektion in `ownProfileSync["rudolstadt-2026"]`.
Diese Sicherungen nicht zur Fehlersuche löschen. Beschädigte Daten werden nicht ersetzt.

Die erste Anmeldung bindet die lokalen Altdaten an dieses Konto. Weitere Konten
beginnen mit ihrer eigenen Replik, ohne fremde Notizen zu übernehmen. Lokale Änderungen
ohne Anmeldung bleiben erhalten. Der Abgleich läuft während der App-Nutzung; nach
Neustart oder wiederhergestellter Verbindung werden gesicherte Änderungen erneut gesendet.
Die Übernahme gilt erst nach Serverbestätigung der gesamten Queue als abgeschlossen.
Alte CloudKit-Daten werden auch dann nicht geladen, wenn der lokale Bestand leer ist.

Für die manuelle Abnahme auf **beiden Geräten mit demselben Firebase-Konto** anmelden.
Vorher eine vorhandene lokale Notiz und einen Merker festhalten. Nach dem Update unter
„Daten & Sync“ auf den erfolgreichen Abgleich warten. Notizen, Merker, Bewertungen und
Badge auf dem anderen Gerät prüfen. Jeweils offline verschiedene Künstler bearbeiten,
die App neu starten und wieder verbinden; beide Änderungen müssen ankommen. Eine
Notiz löschen und das zuvor offline gebliebene Gerät verbinden: sie darf nicht erneut
auftauchen. Danach mit einem anderen Konto anmelden und prüfen, dass dessen Profil
keine privaten Daten des ersten Kontos erhält. Für Freundesprüfungen anschließend
wieder zwei verschiedene Konten verwenden.

## Verifizierter Entwicklungsstand am 4. November 2026

- 31 gezielte JVM-Tests für gemeinsame Freunde und eigenen Profilabgleich erfolgreich.
- Android-Debug-APK erstellt.
- 32 gezielte iOS-Tests für Profil, Persistenz, Konflikte, Notizbearbeitung und lokalen Import erfolgreich.
- Sechs Backend-Unit-Tests und drei Firebase-Integrationstests erfolgreich; zusätzlich
  der private Integrationstest mit wiederholter Notizübertragung ohne Verlaufsduplikate.
- Neue Function im Dev-Projekt aktiv; private Regeln bereitgestellt.
- Keine CloudKit-Importe, -APIs oder -Entitlements mehr im aktiven App-Code.

Nicht durchgeführt: Übernahme auf dem persönlichen iPhone, Anmeldung mit demselben
Konto auf zwei Geräten und visuelle Abnahme der neuen Sync-Anzeige. Die Website-
Datenschutzbeschreibung ist im Repo auf Firebase angepasst; die bestehende Website
wurde im Rahmen des gezielten Backend-Deploys nicht veröffentlicht.

## Profilfarben (Spike, 5. November 2026)

Globale Identitäten speichern `{ name, hue }`; der private `profile`-Datensatz
speichert `badgeName` und `hue` neben Schlüssel und Version. `hue` ist eine endliche
Zahl in Grad von 0 (einschließlich) bis 360 (ausschließlich), auch mit Nachkommastellen.
Die Functions lehnen andere Werte ab. Hex-Farben, RGB, Sättigung und Helligkeit
werden für Profilfarben nicht gespeichert.

`ProfileColors` im gemeinsamen Multiplatform-Kern erzeugt mit der vorhandenen
OKHSL-Umrechnung sRGB für SwiftUI und Compose. Sättigung `0.72` und Helligkeit `0.48`
sind Darstellungskonstanten; der Standard-Hue ist `30`. Die Badge-Beschriftung ist
auf beiden Plattformen weiß; die gemeinsame Helligkeit gewährleistet dafür über
den gesamten Farbkreis mindestens 4,5:1 Kontrast zur Grundfarbe. Der lokale Hue wird auf
eine Umdrehung normalisiert, ungültige lokale Werte erhalten den Standard.

Die bisherigen Farbwerte werden im Entwicklungsprojekt zurückgesetzt. Alte lokale
Hex-Felder werden ignoriert. Es gibt ausdrücklich keine Übernahme oder
Rückwärtskompatibilität für diese Spike-Farbwerte. Die Testkonten verwenden feste
unterschiedliche Hues; ihre übrigen Profildaten und Freundschaften bleiben bestehen.
