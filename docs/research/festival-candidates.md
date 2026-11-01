# Weitere Festivals für das App-Konzept

Stand: 20. Oktober 2026. Diese Recherche untersucht öffentlich zugängliche Primärquellen. Die Downloads liegen außerhalb des App-Projekts unter `/Users/leon/.codex/visualizations/2026/10/20/01a15738-a350-75d0-b0da-cafba396c60b/weitere-festivals/`. Es wurde noch kein anderes Festival in die App eingebaut. Zahlen sind Auswertungen der gesicherten Daten, keine ungeprüften Werbeangaben.

## Internationales Straßenmusikfestival Ludwigsburg 2026

**Sehr gute Passung:** Dieselben Musiker wechseln zwischen vielen Bühnen. Aus dem [offiziellen Zeitplan](https://strassenmusikfestival.de/spielzeiten/) wurden **219 Auftritte von 37 Acts auf 11 Bühnen** für den 20. und 21. Juni 2026 erfasst. Alle 37 Acts treten mehrfach auf: 36 Acts mit sechs Terminen, ein Act mit drei Terminen. Das bietet einen besonders guten Anwendungsfall für Bewertungen, Alternativtermine und einen persönlichen konfliktfreien Zeitplan.

Die Quelle enthält für jeden Slot Beginn, Ende, Bühnenname, Bandnummer und einen Link zum Künstlerprofil. Zusätzlich gibt es [Künstlerprofile](https://strassenmusikfestival.de/kuenstler-bands/), Bühnenprofile, einen [offiziellen Bühnenplan als PDF](https://strassenmusikfestival.de/wp-content/uploads/2026/06/SMF26_Buehnenplan.pdf) sowie einen [Lageplan als PDF](https://strassenmusikfestival.de/wp-content/uploads/2026/06/SMF2026_Lageplan.pdf). Die Webseite verlinkt außerdem die öffentliche [WordPress-REST-Repräsentation ihrer Spielzeitenseite](https://strassenmusikfestival.de/wp-json/wp/v2/pages/468); das ist eine HTML-Seite in JSON, keine eigens strukturierte Termin-API.

Gesichert unter `strassenmusik-ludwigsburg/2026/`:

- `program.json`: normalisierte Slots mit Datum, Beginn/Ende, Künstlernummer/-URL und Bühne; Zählungen und Auftritte je Künstler.
- `timetable.html`, `timetable-page-api.json`, `artists.html`: Originalantworten.
- `artists/*.html`: 37 Künstlerprofile und die Seite zum Preisträgerkonzert.
- `stages/*.html`: elf Bühnenprofile.
- `SMF26_Buehnenplan.pdf`, `SMF2026_Lageplan.pdf`: Original-PDFs.
- `sources.json`: URL, Dateiname, Abrufgröße, Content-Type und SHA-256 jeder Originaldatei.

**Quellfehler:** Zusätzlich zu den 219 regulären Auftritten existiert ein Preisträgerkonzert-Eintrag mit `22:00–22:00`. Die Einleitung derselben Spielzeitenseite nennt dafür 20 Uhr. Der Eintrag ist unverändert übernommen und ausdrücklich mit `sourceIssue` markiert; er darf bei einer späteren Einbindung keine scheinbar verlässliche Dauer erhalten. Es gibt keine doppelt übernommenen Terminzeilen.

## Bardentreffen Nürnberg 2026

**Gute, aber für die Mehrfachauftritt-Funktion schwächere Passung:** Das [offizielle Archiv](https://bardentreffen.nuernberg.de/festival/archiv) verlinkt **96 Auftrittsseiten für 2026 mit 92 unterschiedlichen Veranstaltungstiteln an neun Orten**. Alle 96 verlinkten Seiten wurden gesichert und enthalten Datum, Beginn und Spielort. Der Begriff „Titel“ ist hier absichtlich weiter als „Künstler“, weil auch Mitmach- und Filmveranstaltungen zum Programm gehören.

Vier Künstler sind im veröffentlichten Programm mit je zwei eigenständigen Auftritten vertreten: **Magalí Sare & Manel Fortià, Deitsch, Lavinia Mancusi und Rackajam**. Das ist ein realer Anwendungsfall für die Terminwahl, allerdings mit deutlich weniger Wiederholungsauftritten als Ludwigsburg. Zum Beispiel führen die beiden offiziellen Seiten von Magalí Sare & Manel Fortià [zum Konzert](https://bardentreffen.nuernberg.de/bands/2026-magali-sare-manel-fortia) und [zum zweiten Termin](https://bardentreffen.nuernberg.de/bands/2026-magali-sare-manel-fortia-1).

Gesichert unter `bardentreffen/2026/`:

- `program.json`: alle 96 Termine, Original-IDs, Titel/Länderangaben, Datum, Beginn, Spielort, Beschreibung und Bild-URL.
- `pages/*.html`: alle 96 Original-Auftrittsseiten.
- `archive.html`, `venues.html`, `media.html`: offizielles Archiv und Begleitinformationen.
- `documents-*.pdf`: offiziell verlinkter Spielstättenplan und Presseinformation zum Programm.
- `sources.json`: Quellen und Prüfsummen.

**Grenzen:** Die archivierten Einzelauftrittsseiten enthalten keine Endzeiten. Es wurden keine Konzertdauern geschätzt. Spontane, nicht programmierte Straßenmusik ist nicht erfasst. Der aktuell auf der [Medienseite](https://bardentreffen.nuernberg.de/medien) verlinkte Spielstättenplan trägt im Dateinamen **2025**; er ist deshalb nur als ältere Orientierungshilfe gespeichert, nicht als verifizierter Lageplan von 2026. Bilder sind als Original-URLs in den gesicherten HTML-Seiten und der JSON-Datei enthalten; die Fotos selbst wurden nicht massenhaft heruntergeladen.

## Internationales Dixieland Festival Dresden 2026

**Konzeptionell sehr gute Passung, Datenbestand derzeit nur teilweise nutzbar:** Das vom Veranstalter veröffentlichte [Kurzprogramm mit Stand 17. April 2026](https://www.dixielandfestival-dresden.com/images/downloads/festivalprogramm-pdf/IDF2026-Kurzprogramm-DIN-A4-2026-04-17.pdf) beschreibt eine Festivalwoche vom 10. bis 17. Mai mit wiederkehrenden Bands an Clubs, Konzertsälen, Jazzmeilenbühnen und auf mehreren Schiffen. Beispielsweise erscheint Sunshine Brass an mehreren Tagen und an verschiedenen Orten. In dieser Quelle stehen allerdings häufig nur die Zeitfenster einer Sammelveranstaltung und deren beteiligte Bands, keine belastbaren Einzelset-Zeiten pro Band.

Direkte HTTP-Downloads der offiziellen Seiten/PDFs lieferten **403 Forbidden**. Der Web-Recherchedienst konnte öffentliche, bereits indexierte Textextrakte der Programm-PDFs liefern; beim anschließenden Öffnen wurde das April-PDF dort mit 404 gemeldet. Unter `dixieland-dresden/2026/` liegen deshalb ausschließlich als solche benannte **Web-/Cache-Textextrakte**, kein erfolgreich heruntergeladenes Original-PDF und kein vollständiger App-Datensatz. März- und Aprilstände sind getrennt erkennbar; sie wurden nicht stillschweigend zu einem vermeintlich aktuellen Programm zusammengefügt.

**Aktualität beachten:** Die in den alten PDF-Ständen angekündigte Parade wurde laut [offizieller Mitteilung vom 6. Mai 2026](https://www.dixielandfestival-dresden.com/news/dixieland-parade-2026-abgesagt.html) abgesagt. Die [aktuelle Programmübersicht](https://www.dixielandfestival-dresden.com/programm.html) ist inzwischen auf 2027 umgestellt. Dresden eignet sich deshalb als weiterer Kandidat, sobald ein vollständiger, versionsklarer Satz tatsächlicher Einzeltermine verfügbar ist; die gesicherten PDF-Texte reichen für die in der App benötigte Genauigkeit noch nicht aus.

## Empfehlung aus diesen drei Kandidaten

**Ludwigsburg zuerst:** vollständige, maschinenlesbare Termine inklusive Ende und die mit Abstand höchste Dichte nachweisbarer Mehrfachauftritte. **Bardentreffen danach:** vollständige veröffentlichte Auftrittsliste, allerdings ohne Endzeiten und mit weniger Wiederholungen. **Dixieland Dresden als Recherchekandidat behalten:** passendes Veranstaltungsmodell, aber derzeit keine gleichwertig vollständige und aktuelle Datengrundlage gesichert.

## Fusion Festival 2026

**Sehr gute Passung für viele parallele Bühnen, auch echte Wiederholungsauftritte:** Der [offizielle mobile Timetable](https://timetable.fusion-festival.de/) lädt seine Daten als öffentliches [Künstler-Datenmodul](https://timetable.fusion-festival.de/assets/artists-Ccbu3CeR.js). Im gesicherten Stand sind **1.428 Programmeinträge mit 1.532 Terminen und 47 unterschiedlichen Spielort-Bezeichnungen** enthalten. **80 Einträge haben mehr als einen Termin; 31 davon gehören zu DJ, Band oder Live Act.** Beispiele sind AJATE (zwei Termine), Alizarina (drei) und FLVRS (vier). Diese Zahlen wurden aus stabilen Quell-IDs und deren `shows`-Listen berechnet, nicht aus ähnlich geschriebenen Namen geschätzt.

Gesichert unter `fusion/2026/`: Original-Datenmodul, die vollständige [offizielle Programmseite](https://fusion-festival.de/de/program), abgeleitete `artists.json`, `events.json`, `stages.json`, `summary.json` und rohe Kartenfeatures aus der Timetable-Anwendung. Die Künstlerdaten enthalten teilweise deutsche/englische Beschreibungen, Genres, Webseiten und Hörproben; die Termine liefern IDs, Beginn **und Ende mit Zeitzonenoffset** sowie Spielortnamen. Nicht jeder Eintrag hat eine Beschreibung. Foto- und Länderfelder liefert dieses Datenmodul nicht; die ergänzend gesicherte Programm-HTML-Seite wurde dafür noch nicht normalisiert.

**Grenzen:** Die 47 Bezeichnungen umfassen auch Unterbereiche des Workshop-Hangars und „Outdoor“. Sie sind keine Behauptung über 47 eigenständige Konzertbühnen. Die Kartenelemente sind noch nicht mit den Termin-Spielorten abgeglichen. Der Stand der Anwendung ist laut Bundle der 28. Juni 2026; einige Termine reichen bis zum 29. Juni. Er wird als gespeicherter Programmstand behandelt, nicht als Zusicherung eines nachträglich bereinigten Abschlussprogramms.

## at.tension Theaterfestival 2026

**Besonders gute Passung für wiederholte Vorstellungen, mit anderem inhaltlichen Schwerpunkt:** Der [offizielle Timetable 2026](https://timetable.attension-festival.de/) lädt ebenfalls ein öffentliches [Programmmodul](https://timetable.attension-festival.de/assets/artists.attension-0NueOyOL.js). Gesichert sind **329 Programmeinträge, 764 Termine und 68 Spielort-Bezeichnungen**. **138 Einträge haben mehrere Termine.** Hier überwiegen Theater, zeitgenössischer Zirkus, Performance und Workshops; nur sechs wiederholte Einträge tragen die untersuchten Musik-Kategorien. Das Konzept „gute Vorstellung auswählen und Überschneidungen vermeiden“ passt sehr gut, die musikalischen Entdeckungsfunktionen nur eingeschränkt.

Unter `at-tension/2026/` liegen Originalmodul und normalisierte Künstler-/Programm-, Termin- und Spielort-JSON samt Zusammenfassung. Zusätzlich zu Beschreibungen und Zeiten liefert die Quelle je nach Eintrag Altersempfehlung, Sprache, Mitwirkende, Kategorie und Dauerangaben. Die 68 Spielort-Bezeichnungen enthalten nummerierte Plätze, Varianten desselben Orts und `Outdoor (tba)`; sie sind keine bereinigte Zahl baulicher Bühnen. Die Termine enthalten echte Kalenderdaten im September und reichen im Snapshot teilweise bis zum 7. September.

**Kartengrenze:** Im Anwendungsbundle eingebettete rohe Kartenfeatures sind separat erhalten, enthalten aber unter anderem Fusion-Bühnennamen. Sie sind ausdrücklich **nicht als verifizierte at.tension-Spielortkoordinaten** importiert oder zugeordnet.

## Tollwood Sommerfestival München 2026

**Für eine breitere Kulturprogramm-App geeignet; weniger stark für die Wahl zwischen mehreren Auftritten derselben Band:** Aus dem Kalender des [offiziellen Rückblicks 2026](https://www.tollwood.de/rueckblick-sommerfestival-2026/) sind **568 Programmpunkte an 13 Spielorten** gesichert, davon **177 Musiktermine an sechs Orten**. Die Musiktermine haben 125 unterschiedliche Titel. Zehn Titel kommen mehrfach vor, allerdings gehören dazu unbestimmte Reihen wie „Live-Musik“ und „Pub-Musik“; daraus dürfen keine zehn sicher identifizierten mehrfach auftretenden Künstler abgeleitet werden. Als konkret benannte Beispiele sind Mama’s Greens und Gerhard Polt und die Well-Brüder jeweils zweimal enthalten.

Gesichert unter `tollwood/2026/`: die vollständige Kalender-HTML-Antwort, der [offizielle Gesamtspielplan als Original-PDF](https://www.tollwood.de/wp-content/uploads/2026/04/tw-so26-spielplan.pdf), normalisierte `events.json`, `stages.json` und `summary.json`. Der HTML-Kalender enthält 1.432 Tabellenzeilen für verschiedene responsive Ansichten. Identische Termine wurden anhand Datum, Titel, Kategorie, Ort, Zeittext, Eintritt und Ziel-URL entfernt; übrig bleiben 568 Einträge. Bei allen Termin-URLs mit eingebettetem Datum stimmt dieses mit dem erfassten Kalendertag überein.

**Grenzen:** Beginn/Ende stehen zunächst als Original-Zeittext zur Verfügung; Angaben wie „max. 22:00“ werden nicht in vermeintlich exakte Endzeiten umgedeutet. Die Detailseiten wurden nicht flächendeckend heruntergeladen. Deshalb fehlen gesondert normalisierte Künstlerbeschreibungen, Bilder und Koordinaten. Das Sommerprogramm verteilt sich vom 19. Juni bis 19. Juli über einen Monat, anders als Rudolstadts kompaktes Festivalwochenende.

## Reeperbahn Festival Hamburg

Als bekanntes Clubfestival bleibt Reeperbahn ein sinnvoller Kandidat. Die [offizielle Hauptseite](https://www.reeperbahnfestival.com/) lieferte beim Webabruf eine JavaScript-Roboterprüfung; der direkt versuchte Programmpfad `/de/programm` lieferte HTTP 404. Daraus folgt **nicht**, dass es keine Programmdaten gibt. In dieser Recherche wurde lediglich kein vollständiger offizieller Datensatz gesichert. Es wurden keine ungeprüften Drittanbieter-Timetables als offizielle Daten übernommen.

## Gemeinsame Bewertung und Ablage

Für den nächsten Musikfestival-Adapter würde ich **Ludwigsburg** wählen: fast derselbe Planungsfall wie Rudolstadt, mit vielen Alternativterminen für jeden Act. **Fusion** ist der stärkste große Belastungsfall für viele parallele Orte und ein umfangreiches, bereits strukturiertes Programm. **Bardentreffen** passt kulturell gut, braucht aber einen sauberen Umgang mit unbekannten Endzeiten. **at.tension** wäre ein sehr guter eigener Test für Theater/Performance und häufig wiederholte Vorstellungen. **Tollwood** bleibt ein brauchbarer breiterer Kalenderfall. **Dixieland Dresden und Reeperbahn** sind vorerst Recherchekandidaten mit unvollständig gesicherter Datengrundlage.

Die Sammlung enthält Originalantworten, Quellenmetadaten und davon getrennte Ableitungen. Bilder sind soweit vorhanden als Quell-URLs erhalten; es wurde kein vollständiges Fotoarchiv angelegt. Es gibt noch keine Einbindung dieser Festivals in die App und keine Änderung ihres Profilspeichers.
