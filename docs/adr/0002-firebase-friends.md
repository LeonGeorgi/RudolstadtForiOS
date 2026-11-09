# 0002: Profilabgleich und Freunde mit Firebase

Status: Entwicklungsimplementierung, aktualisiert am 5. November 2026.

Die Freundschafts- und Freigabeabschnitte werden durch
[ADR 0003](0003-global-friendships.md) ersetzt: Freundschaften gelten jetzt global,
Freigaben werden je Freund gesetzt und können auch aktuelle Notizen umfassen.

Diese Entscheidung ersetzt die Apple-Beschränkung und CloudKit-Anbindung aus
ADR 0001. Die Sync- und Freundesabläufe liegen in Kotlin Multiplatform; native
Firebase-SDKs, Anmeldung, Persistenz und Oberflächen bleiben in Swift und Kotlin.

## Produktvertrag

- Nutzung ohne Konto bleibt lokal möglich. Geräteabgleich und Freunde benötigen Anmeldung.
- Apple-, Google- und passwortlose E-Mail-Anmeldung sind implementiert. Google
  benötigt den aktivierten Anbieter und aktualisierte Firebase-SDK-Dateien.
  Kontolöschung erhält das eigene Profil lokal und entfernt die Firebase-Daten.
- Das Verknüpfen von Anmeldearten ist keine App-Funktion (Entscheidung vom
  5. November 2026). Eine entsprechende Kontoverwaltungsoberfläche ist nicht vorgesehen.
- Ein geheimer Zugangsschlüssel ist eine zusätzliche Anmeldeoption ohne E-Mail-Adresse.
  Er erstellt ausschließlich ein eigenständiges Schlüssel-Konto. Apple-, Google- und
  E-Mail-Konten können keine Zugangsschlüssel erhalten.
  Wer den Schlüssel besitzt, kann auch die privaten Notizen dieses Kontos lesen.
- Derselbe Firebase-Nutzer synchronisiert sein aktuelles Rudolstadt-Profil samt
  Merkliste, Bewertungen, Badge und privaten Notizen zwischen iOS und Android.
- Freundschaften gelten über Festivals und Jahre. Je Freund sind Merker,
  Bewertungen und aktuelle Notizen unabhängig freigebbar. Notizen sind zunächst
  privat; ihr Verlauf bleibt ausschließlich beim eigenen Konto.
- Einladungen gelten sieben Tage, sind einmalig einlösbar und werden durch eine
  neue Einladung ersetzt. Annahme verlangt ausdrückliche Zustimmung nach Vorschau.
- Beenden entfernt beide Firebase-Freigaben über alle Ausgaben.

## Lokale Übernahme und Ende von CloudKit

CloudKit ist vollständig aus der aktiven App entfernt, einschließlich Engines,
Freigabedialogen, Delegates und Entitlements. Fehlende Firebase-Konfiguration führt
zu lokalem Betrieb. Vorschauen, Screenshots und Unit-Tests starten keinen Firebase-Abgleich.

Übernommen werden ausschließlich auf dem Gerät vorhandene Altdaten. CloudKit wird
weder abgefragt noch verändert; nur dort vorhandene Daten und Freundschaften werden
ignoriert. Bestehende remote Freigaben werden nicht widerrufen. Ältere App-Versionen
können diese weiterhin verwenden; die neue App greift nicht mehr darauf zu.

Vor dem ersten Netzwerkschreiben wird ein lokales Journal mit Originalbackup,
Versionen und ausstehenden Änderungen gespeichert. iOS sichert zusätzlich den
ursprünglichen nativen Cache. Das alte lokale Format bleibt lesbar, einschließlich
opaker Systemfelder, die nicht mehr ausgewertet werden. Unlesbare Journale führen
zu einem sichtbaren Fehler und niemals zu einem leeren Ersatzprofil.

Die lokalen Altdaten werden dem ersten angemeldeten Firebase-Konto zugeordnet.
Kontowechsel verwendet getrennte Repliken und kopiert keine privaten Werte zum
anderen Konto. Erneute Anmeldung stellt dessen lokalen beziehungsweise entfernten
Stand wieder her. Archive und experimentelle Festivalprofile bleiben lokal.

## Gemeinsamer eigener Profilabgleich

`OwnProfileController` besitzt Journal, lokale Übernahme, Kontowechsel, ausstehende
Änderungen, Wiederholungen und Listener. `OwnProfileTransport` verbindet ausschließlich
native Speicherung und Firebase. Jede Änderung wird zuerst lokal gesichert.
Notizentwürfe werden sofort gespeichert; der Netzwerkversand wartet 600 ms.

Pro Merker, Künstlerbewertung und Notiz gibt es einen versionierten Datensatz;
Name und Farbe bilden gemeinsam den Badge-Datensatz. Zeitstempel und Änderungs-ID
entscheiden Konflikte deterministisch. Löschungen bleiben als Tombstones erhalten.
Fehlende Datensätze bedeuten keine Löschung. Serverbestätigungen entfernen nur die
konkret übertragenen Versionen aus der Queue. Verspätete Ergebnisse alter
Kontositzungen werden verworfen; das Backend bindet jeden Auftrag an dessen UID.

Private Daten liegen unter
`users/{uid}/profileEditions/{festival-year}/records/{key}`. Der
Eigentümer darf sämtliche Datensätze lesen. Freunde dürfen ausschließlich aktuelle
Notizdatensätze lesen, wenn diese explizit für sie freigegeben wurden (ADR 0003).
Schreiben erfolgt über `syncOwnProfile`, nicht direkt vom
Client. Nichtleere Notizversionen werden zusätzlich unter `noteVersions` archiviert,
auch wenn sie einen Konflikt verlieren. Wiederholungen sind anhand der Versions-ID
idempotent. Ein Auftrag enthält höchstens 50 Datensätze; größere Queues werden geteilt.

## Gemeinsame Freunde und getrennte Freigabe

`FriendsController` steuert Zustimmung zur Veröffentlichung, serialisierte Updates,
Einladungen, Widerruf und sämtliche Freundes-Listener. Beide Oberflächen beobachten
denselben `FriendsState`. `FriendsTransport` hält SDK-Objekte und Credentials nativ.
Die eigene Synchronisierung benötigt keine Zustimmung zur Freundesfreigabe.

`friendEditions/{festival-year}/profiles/{uid}` ist eine gesonderte, geprüfte
Leseansicht ohne Notizfeld. Eigentümer und freigegebene Freunde dürfen einzelne
Profile lesen. Functions erstellen zwei Mitgliedschaften und verbrauchen die
Einladung atomar; im Backend liegt nur ihr SHA-256-Hash.

Nach einem Profilzugriffsverlust prüft der Controller die eigene Mitgliedschaft
gegen den Server. Eine entfernte Mitgliedschaft bedeutet normalen Widerruf;
bestehende Mitgliedschaften oder fehlgeschlagene Prüfungen bleiben sichtbare Fehler.
Generationen verhindern, dass alte Listener einen neuen Kontozustand verändern.

## Gemeinsame Schlüsselanmeldung

`AccountKeyController` besitzt Erzeugung, Anmeldung, wiederholbare Aufträge,
Kontobindung und Anzeigedauer. `AccountActionGate` verhindert sich überholende
Anmeldevorgänge beider Controller. Die nativen Adapter liefern ausschließlich
kryptographischen Zufall und Firebase-Custom-Token-Anmeldung; Anzeige, Kopieren
und QR-Code bleiben nativ. Der Schlüssel enthält 160 zufällige Bits mit einem
Formatpräfix, ohne personenbezogene Ableitung. Er wird nur unmittelbar nach der
Erzeugung angezeigt und weder im Profiljournal noch im gespeicherten UI-Zustand abgelegt.

Vier Functions tauschen den Schlüssel gegen ein Custom Token, liefern den
Schlüsselstatus und ersetzen ihn. Nur der normalisierte SHA-256-Hash und eine
unabhängig zufällige UID liegen im Backend. Credential-Dokumente sind für Clients
vollständig gesperrt. Ersetzen verwendet eine transaktionale Versionsprüfung;
verlorene Antworten lassen sich mit demselben Schlüssel wiederholen. Alte Schlüssel
verlieren den Zugang für neue Anmeldungen. Bestehende Gerätesitzungen bleiben bestehen.

Erstellen und Anmelden sind pro gehashter IP-Adresse begrenzt, Schlüsselwechsel
zusätzlich pro UID. Der Status wird nur bei Bedarf geladen. Der Schlüssel lässt
sich bei Verlust nicht aus dem Hash wiederherstellen; ein noch angemeldetes Gerät
dieses Schlüssel-Kontos kann einen Ersatzschlüssel erzeugen.
Das ergänzt die Kontowiederherstellung, ersetzt aber keine Geräteverwaltung.

## Kontolöschung mit lokalem Datenerhalt

`AccountDeletionController` in Multiplatform steuert Bestätigung, dauerhafte lokale
Sicherung, wiederholbare Löschaufträge und Abmeldung. Vor dem ersten Serverauftrag
speichert `OwnProfileController` UID und einen zufälligen Löschbeleg im Journal und
stoppt seinen Netzwerkabgleich. Verbindungsfehler und ein App-Neustart verlieren
weder den Auftrag noch das lokale Profil. Nach Bestätigung werden aktuelle Werte
und ausstehende Änderungen einschließlich privater Notizen zur lokalen Replik,
die alte UID wird dauerhaft vom Sync ausgeschlossen. Andere lokale Kontorepliken
und das Originalbackup bleiben erhalten. Ein gleichzeitig anderes Konto erhält
diese Daten nicht. Auf weiteren Geräten wird ein bestätigter Zugriffsverlust
ebenfalls in lokalen Betrieb überführt.

Die Cloud-Löschung entfernt rekursiv alle privaten Ausgaben und Notizversionen,
Freigabeprofile, beide Freundschaftsrichtungen einschließlich verwaister eingehender
Verbindungen, besessene und eingelöste Einladungen, Schlüssel und UID-bezogene
Anfragelimits sowie Firebase Authentication. Apple-Adapter bestätigen vorab erneut
dieselbe Identität und widerrufen den Apple-Zugang über das native Firebase-SDK.

Ein privater technischer Löschauftrag sperrt Lesezugriffe sofort. Alle schreibenden
Transaktionen prüfen ihn, sodass parallele Geräte keine Daten wieder anlegen.
Ein Firestore-Trigger und eine Wiederholung alle 15 Minuten sichern Serverabbrüche ab.
Der Auftrag enthält nur UID, gehashte Löschbelege und Bearbeitungsmetadaten. Er bleibt
zwei Stunden erhalten, weil vorher ausgestellte Custom Tokens eine Stunde gültig sein
können; danach entfernt der Worker auch diesen Auftrag und gegebenenfalls eine durch
ein altes Token neu entstandene Auth-Hülle. Bei Dienstfehlern bleibt der Auftrag
bis zum erfolgreichen Abschluss bestehen. Die App benötigt keine bestehende
Anmeldesitzung, um einen bereits autorisierten Auftrag mit seinem Beleg fortzusetzen.

## Verifikation und Grenzen

Gemeinsame Tests prüfen lokale Übernahme, Offline-Neustart, konkurrierende Änderungen,
Löschungen, Kontowechsel, Speicherfehler, verlorene Antworten und verzögerten Versand.
Firebase-Emulatortests prüfen echte Functions-Aufrufe und Regeln einschließlich des
Ausschlusses privater Notizen für akzeptierte Freunde. Native Tests prüfen das alte
lokale Speicherformat. Die Übernahme auf dem persönlichen iPhone und der Abgleich
mit demselben Konto auf zwei Geräten bleiben eine gesonderte manuelle Abnahme.

Der Stand verwendet ausschließlich das Entwicklungsprojekt. Vor einem Release
bleiben App Check und umfassende Missbrauchsgrenzen zu bearbeiten.
