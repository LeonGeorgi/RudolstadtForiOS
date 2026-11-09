# 0003: Festivalübergreifende Freundschaften

Status: implementiert im Entwicklungsprojekt, 5. November 2026.

Diese Entscheidung ersetzt die ausgabenbezogenen Freundschaften und die grundsätzlich
ausgeschlossenen Notizen aus ADR 0002. Bestehende Freundschaften und Einladungen
werden ausdrücklich nicht übernommen; eigene Konten und Profilrepliken bleiben erhalten.

## Produktvertrag

Eine Freundschaft verbindet zwei Firebase-Konten dauerhaft über Festivals und Jahre.
Die aktuellen Oberflächen teilen automatisch Konzertmarkierungen und Bewertungen
samt Symbolen. Notizen und Notizversionen bleiben privat. Name und Farbe identifizieren
die Person. Es gibt keine Auswahl oder Bearbeitung von Freigaben im Frontend.

`FriendSharing.defaultPermissions` definiert die gemeinsame Vorgabe als
`{ savedEvents: true, ratings: true, notes: false }`. Einladen und Annehmen verwenden
sie ohne native Konfigurationslogik. Der gemeinsame Controller lädt keine
Freundesnotizen, auch wenn ältere Datensätze eine Notizfreigabe enthalten.

Die Backend-Schnittstellen, Berechtigungsfelder und Regeln bleiben für eine spätere
Rückkehr zu individuellen Freigaben bestehen. Ihre Modelldefaults bleiben sicher
auf `false`; die feste App-Vorgabe ist ein eigener, expliziter Wert. Bestehende
Freundschaften und Einladungen im Entwicklungsprojekt werden auf diese Vorgabe
angepasst. Eigene Notizen und ihre Synchronisierung bleiben erhalten.

Einladungen bleiben sieben Tage und einmalig gültig; eine neue ersetzt die
vorherige. Eine erneute Verbindung bereits befreundeter Konten erstellt keine
zweite Freundschaft. Das Beenden wirkt festivalübergreifend.

## Gemeinsame Abläufe

`FriendPermissions`, `FriendshipRecord`, `FriendConnection`, `FriendInvite` und
`FriendsController` liegen in Multiplatform. Der Controller beobachtet globale
Identität und Freundschaften und abonniert ausschließlich erlaubte Markierungen und Bewertungen.
Beim Öffnen eines Rudolstadt-Archivs liest er zusätzlich die freigegebenen Inhalte
des gewählten Jahres. Für Archivänderungen aktualisiert der Profilabgleich die
betroffene Freigabe atomar mit dem privaten Datensatz.
Widerrufene Inhalte werden sofort entfernt. Verspätete Ergebnisse alter Listener
und Kontositzungen werden verworfen.
Unklarer Zugriffsverlust wird über `friendConnectionStatus` gegen den Server geprüft.

Ein globales Freundesprofil muss einmal eingerichtet werden und wird danach beim
Anmelden wiederhergestellt. Eine neue Festivalausgabe benötigt weder Aktivierung noch
Einladung. Der Versand von Merker-/Bewertungsansichten wartet auf die zusammengeführte
eigene Profilreplik, damit ein neues Gerät keine entfernten Daten durch einen noch
unvollständigen Cache ersetzt. Globale Identitätsänderungen sind explizite Aktionen;
der Profilabgleich einer Festivalausgabe kann den Anzeigenamen nicht überschreiben.

## Server und Zugriffsgrenzen

- `friendIdentities/{uid}` enthält ausschließlich `name` und den numerischen
  OKHSL-`hue` in Grad (`0 <= hue < 360`). Sättigung und Helligkeit sind gemeinsame
  Darstellungskonstanten in Multiplatform. Einzelzugriff
  erfolgt durch Eigentümer und verbundene Freunde, keine öffentliche Suche.
- `friendships/{uid}/friends/{other}` enthält `uid`, `sharing` und gespiegeltes
  `receiving`. Erstellen, Freigabeänderungen und Beenden schreiben beide Richtungen
  atomar. Clients können nur ihre eigene Liste lesen, niemals selbst schreiben.
- `friendProfileEditions/{edition}/profiles/{uid}/categories/savedEvents` und
  `ratings` enthalten getrennte Daten ohne Notiztext. Regeln prüfen für jeden Zugriff
  die jeweilige ausgehende Berechtigung des Eigentümers. Feldverstecken im Client
  ersetzt keine Zugriffskontrolle.
- Notizen verwenden die bereits synchronisierten aktuellen `records` unter
  `users/{uid}/profileEditions/{edition}`. Nur mit `sharing.notes == true` darf ein
  Freund Notizdatensätze lesen. Listenabfragen müssen `value.kind == "note"` filtern;
  andere private Datensätze und die gesamte `noteVersions`-Sammlung bleiben gesperrt.
  Dadurch entstehen weder zusätzliche Textkopien noch Größenprobleme durch ein
  Sammeldokument mit mehreren großen Notizen.
- `friendInvitesV2/{sha256}` enthält eine globale Einladung und ihre Freigabeauswahl,
  keine Festivalausgabe. Der Link ist versioniert mit `v=2`. Alte Links und alte
  ausgabenbezogene Datenpfade geben keinen Zugang zum neuen Modell.

Alle Freundes-Functions binden Aufträge an die authentifizierte UID und verlangen
Protokollversion 2. Ausgabenkennungen werden nur für Festivalinhalte benötigt.
Kontolöschung erfasst die neuen Pfade sowie weiterhin alle alten Daten, beide
Freundschaftsrichtungen und beide Einladungsformate. Die bestehende Löschsperre
schützt auch globale Schreibvorgänge und sämtliche freigegebenen Lesepfade.

Bereits heruntergeladene Inhalte können nicht auf fremden Geräten zurückgerufen
werden. Sobald das Gerät den Widerruf empfängt, werden sie in der App ausgeblendet.

## Verifikation

Gemeinsame Tests und echte Auth-/Functions-/Firestore-Emulatortests prüfen unabhängige
Freigaben, mehrere Festivals ohne erneute Verbindung, Widerruf und verspätete
Callbacks, explizite aktuelle Notizen bei gesperrtem Verlauf, alte Einladungen,
Kontowechsel und vollständige Kontolöschung. Manuelle Oberflächenprüfungen bleiben
auf Nutzerwunsch separat.
