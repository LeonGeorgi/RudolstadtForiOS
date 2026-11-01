# Ludwigsburg 2026: Bühnen und weitere Orte

Stand: 20. Oktober 2026. Recherche gegen öffentliche Veranstalterquellen; keine amtlichen GPS-Positionen gefunden; auf ausdrücklichen Nutzerwunsch anschließend ungefähre Koordinaten aus einem Kartenabgleich kuratiert.

## Ergebnis

Die Orte sind vorhanden: Der [offizielle Festival-Lageplan 2026](https://strassenmusikfestival.de/wp-content/uploads/2026/06/SMF2026_Lageplan.pdf), auf der [Spielzeiten-Seite](https://strassenmusikfestival.de/spielzeiten/) verlinkt, markiert die Bühnen A, B, C, D, E, F, G, H, I, K und M. Der Plan ist eine illustrative, perspektivische Parkansicht. Eine öffentliche maschinenlesbare Liste der elf GPS-Positionen oder eine offizielle interaktive Bühnenkarte wurde nicht gefunden.

Die ursprünglichen Planpositionen werden separat von geografischen Koordinaten
geführt. Auf Nutzerwunsch wurden die Teilbereiche mit einer geografischen Karte
abgeglichen. Die abgeleiteten Pins sind ausdrücklich ungefähre Positionen und
liefern weder vermessene Veranstalterkoordinaten noch belastbare Gehzeiten.

## Weitere Inhalte des offiziellen Plans

Die folgende Aufstellung ist eine strukturierte Erfassung der Beschriftungen und Symbolbedeutungen, keine zusätzliche Ortsbestätigung außerhalb des Plans.

| Gruppe | Beschriftungen und Angebote |
| --- | --- |
| Nummerierte Orte | 1 Haupteingang; 2 Eingang Mömpelgardstraße; 3 Eingang Marbacher Straße; 4 Eingang Kaffeeberg; 5 Café am Rosengarten; 6 Eingang Märchgarten; 7 Parkcafé/Restaurant; 8 Eingang Hinterer Schlosshof; 9 Eingang Parkcafé |
| Gastronomie | Restaurant Parkcafé; Café am Rosengarten mit Cool-Down-Area; Märchenimbiss; Bistro; Biergarten; Getränke; vegetarische Gerichte; internationale Gerichte |
| Versorgung | DRK; Toiletten; barrierefreie Toiletten mit Toiletten/Wickelräumen; Parkplätze Pkw; Parkplätze Bus |
| Parkmöglichkeiten außerhalb des Plans | Parkplatz Bärenwiese; Parkhaus Rathaus/Mathilde; Parkhaus MARSTALL. Pfeile weisen aus dem Plan hinaus; die Textposition ist kein genauer Parkplatzstandort. |
| Weitere Angebote | Sparda Giro Lounge; Sparda Hutgeld-Wechselstube; Sparda-Mobil; Walk of Fame/Cocktailbar/Imbiss; Gaukler:innen und Artist:innen; Rollende Kinderturn-Welt; Mitmachzirkus |
| Ohne eindeutig eigenes Plansymbol | Kinderschminken und Fotobox stehen in der Legende, eine konkrete Position ist visuell nicht eindeutig zugeordnet. |

Quelle für die Tabelle: [offizieller Lageplan](https://strassenmusikfestival.de/wp-content/uploads/2026/06/SMF2026_Lageplan.pdf). Schreibweise „Märchgarten“ bei Nummer 6 entspricht dem PDF; in einer eigenen UI kann sie zu „Märchengarten“ berichtigt werden.

### Zugänge und Richtungsverweise

Nummern 5 und 7 bezeichnen Gastronomie, keine Zugänge. Die Beschriftungen der
Zugänge und die Pfeilsymbole sind im Originalplan erhalten. Aus der Illustration
werden keine garantierten Öffnungs-, Zugangs- oder Routingregeln abgeleitet.

## Geprüfte technische Quellen

- Alle elf offiziellen Bühnen-HTML-Seiten (`/buehne/hauptbuehne/`, `/buehne/b/` bis `/buehne/i/`, `/buehne/k/`, `/buehne/buehne-m/`) wurden direkt abgerufen. Sie enthalten Spielzeiten; keine Treffer für `latitude`, `longitude`, `data-lat`, `data-lng`, Leaflet, GeoJSON, Mapbox oder eingebettete Karten. Beispiel: [Bühne B](https://strassenmusikfestival.de/buehne/b/).
- Der öffentliche [WordPress-API-Index](https://strassenmusikfestival.de/wp-json/) zeigt keinen Bühnen- oder Geo-Endpunkt. [Post-Typen](https://strassenmusikfestival.de/wp-json/wp/v2/types) liefern `post`, `page`, `attachment` und `wp_block`; [Taxonomien](https://strassenmusikfestival.de/wp-json/wp/v2/taxonomies) nur Kategorien und Schlagwörter. Das schließt nicht öffentliche Metadaten nicht aus.
- Die [Festival-Anfahrt](https://strassenmusikfestival.de/anfahrt/) bettet nur eine allgemeine Google-Maps-Ansicht des Blühenden Barocks ein. Deren Kartenzentrum ist keine Bühnenkoordinate.
- Die [Downloadseite des Parkbetreibers](https://www.blueba.de/de/downloads.html) verlinkt Übersichts- und Wegepläne als PDFs, keine erkennbare interaktive Festivalkarte. Die [Anfahrt des Parkbetreibers](https://www.blueba.de/de/anfahrt-parken.html) liefert Anschrift und Verkehrsinformationen.
- Im lokal gespeicherten Festival-PDF fehlen die üblichen unkomprimierten GeoPDF-Marker `/LGIDict`, `/Viewport`, `/VP`, `/Measure`, `/GCS`, `/GPTS`, `/LPTS`. Zusammen mit der visuellen Ansicht ist dies kein belastbarer georeferenzierter Datensatz; eine formale vollständige PDF-Objektanalyse wurde nicht durchgeführt.

## Umsetzung

Die Testeinbindung speichert das unveränderte PDF offline und erfasst 49 Einträge:
elf Bühnen und 38 weitere Orte bzw. Angebote. Normalisierte Planpositionen beziehen
sich auf die gesamte PDF-Seite, Ursprung oben links. Bei externen Parkplätzen,
Kinderschminken und Fotobox fehlt eine eindeutige Position; diese Einträge enthalten
statt eines Punkts einen erklärenden Hinweis. Die Zuordnung ist manuell kuratiert,
mit dem SHA-256 des konkreten Plans verbunden und vom Programmimport getrennt.
Die Ortseinträge ersetzen keine GPS- oder Zugangsbestätigung.


## Geografischer Abgleich

Norden zeigt im PDF diagonal nach rechts unten. Der oben abgebildete Garten ist
also der reale Südgarten. Der Park wurde in OpenStreetMap visuell geprüft und
mit den öffentlichen [OSM-Kartendaten](https://www.openstreetmap.org/way/10870895)
verglichen. Feste lokale Bezugspunkte sind unter anderem:

| Bezugspunkt | OSM-Objekt | Breite | Länge |
| --- | --- | --- | --- |
| Südgartenbassin | [way 44679198](https://www.openstreetmap.org/way/44679198) | 48.897704 | 9.196092 |
| Rundbassin Nordgarten | [way 236043572](https://www.openstreetmap.org/way/236043572) | 48.901729 | 9.194869 |
| Schüsselesee | [way 45697410](https://www.openstreetmap.org/way/45697410) | 48.899885 | 9.201001 |
| Mömpelgard-Zugang | [node 1342051099](https://www.openstreetmap.org/node/1342051099) | 48.898739 | 9.197625 |
| Parkcafé | [way 206651166](https://www.openstreetmap.org/way/206651166) | 48.899619 | 9.201999 |
| Café Rosengarten | [node 563317509](https://www.openstreetmap.org/node/563317509) | 48.902292 | 9.197016 |

Die Ansichten wurden bereichsweise abgeglichen. Lokale Interpolation diente als
Arbeitshilfe; anschließend wurden die Bühnenpins visuell gegen Wege, Wasserflächen
und die Schlossbereiche geprüft und kuratiert. Eine einzige globale Transformation
wäre wegen Perspektive und verschobener Beschriftungen ungeeignet. Dezimalstellen
im Datensatz sind keine Genauigkeitszusage. Abweichungen von mehreren zehn Metern
sind möglich; eine statistische Genauigkeitsmessung oder Vor-Ort-Prüfung fehlt.

| Bühne | Ungefähre Breite | Ungefähre Länge |
| --- | --- | --- |
| A | 48.89894 | 9.19542 |
| B | 48.89765 | 9.19665 |
| C | 48.89686 | 9.19620 |
| D | 48.89855 | 9.19728 |
| E | 48.89992 | 9.20162 |
| F | 48.90020 | 9.20040 |
| G | 48.90085 | 9.19840 |
| H | 48.90210 | 9.19990 |
| I | 48.90200 | 9.19710 |
| K | 48.90155 | 9.19564 |
| M | 48.89970 | 9.19837 |

Insgesamt haben 46 der 49 Einträge geografische Pins. Die 44 im Gelände lokalisierten
Planpunkte wurden auf diese Weise abgeglichen. Zwei externe Ziele sind zusätzlich
belegt: [MARSTALL](https://www.marstall-ludwigsburg.de/center/anfahrtparken/parken/)
ist das Center-Parkhaus; dessen [OSM-Parkpunkt](https://www.openstreetmap.org/node/1517558296)
wird verwendet. [Bärenwiese](https://www.swlb.de/baerenwiese) umfasst P03/P04 West
und Ost. Der [Anfahrtslink des Betreibers](https://goo.gl/maps/Be3RApzP2XovDXec6)
liefert das gemeinsame ungefähre Anfahrtsziel 48.8937491, 9.1970766.

„Rathaus / Mathilde“ bleibt ohne Pin: Die [Rathausgarage](https://www.swlb.de/rathausgarage)
ist belegbar, die kombinierte historische Planbezeichnung wurde aber nicht als
identischer einzelner heutiger Ort bestätigt. Auch Fotobox und Kinderschminken
bleiben ohne erfundene Position.

Koordinaten und Herkunft stehen in `scripts/data/ludwigsburg_2026_site_plan.json`.
OSM-Positionen: © OpenStreetMap-Mitwirkende, [ODbL](https://www.openstreetmap.org/copyright).
Diese Quellenangabe ist auch in der geografischen App-Karte vorhanden.
Ungefähre Bühnenpositionen bleiben von automatischer Wegeplanung ausgeschlossen.
