# Orte · iOS · 4. November 2026

In `design/Rudolstadt.sketch` wurde die Seite **Orte** ergänzt:

- `F203F3DE-A48D-4050-B409-6FC2AB03869D`: bearbeitbare Kartenübersicht, 402 × 874 pt.
- `ABB49709-B753-4F1E-850F-1A5122122869`: unveränderte Nutzerreferenz.
- `6BE6459B-D3E6-4E40-83D6-AAA1DB695914`: Codebasis, Interaktionen und Grenzen.

Grundlage sind der vom Nutzer bereitgestellte Screenshot und die aktuellen
Implementierungen `MapOverview.swift`, `MapView.swift`, `StageNumber.swift` und
`RootTabView.swift`. Kein neuer Simulatorlauf und keine Codeänderungen.
Referenz: Deutsch, hell, 1206 × 2622 px bei angenommener Skalierung 3×.
Gerät, OS und Dynamic Type wurden nicht mitgeliefert. Kartenstand, Zoom und
Pin-Anordnung stammen unverändert aus der Referenz.

Titel, Kategorie-Filter samt Farbpunkten, Attribution und die Vektorsymbole für
Liste und Zentrierung sind editierbar. Die drei Filter verwenden eine gemeinsame
Symbol Source mit Inhalts- und Farb-Overrides, bestehende Kategorie-Farbvariablen
und einen gemeinsamen SF-Pro-Textstil (11⅓ pt, Width 100, Optical Size 17,
Weight 510). Die Rundflächen teilen eine Symbol Source. Die vorhandene gemeinsame
Orte-Tab-Leiste bleibt als Instanz verknüpft; ihre Source wurde nicht verändert.

Die native Kartenfläche einschließlich ihrer Beschriftungen und MapKit-Pins ist
ein ausgeschnittenes Bitmap. App-Leisten und Bedienelemente wurden daraus
ausgeschlossen. Herkunft, Masken und Prüfsumme stehen in
`../assets/orte/manifest.json`; die Extraktion ist mit
`../assets/orte/extract_reference.py` reproduzierbar.

## Visuelle Prüfung

Der bearbeitbare Frame wurde unbeschnitten bei 3× exportiert und mit der
Nutzerreferenz verglichen. `channels.png` verwendet die dokumentierte
Magenta-/Grün-Kanaldifferenz mit ausschließlich den oberen 186 px maskiert.
`rgb-difference.png` zeigt zusätzlich die RGB-Differenz; `overlay.png` die
50-%-Überlagerung. Es wurde keine automatische Ausrichtung angewendet.

Kartenposition, Pin-Anordnung und Hierarchie der Bedienelemente stimmen mit der
Referenz überein. Der Screenshot bestätigt lesbare, nicht abgeschnittene Texte;
der dritte Filter wird wie in der Referenz am rechten Bildschirmrand beschnitten.
Glass-Flächen und der aus einem textfreien Streifen gewonnene Navigationshintergrund
sind angenähert. Unterschiede bleiben bei Glyphenmetriken und einzelnen
Symbolkonturen, der Attribution, der gemeinsamen Tab-Leiste sowie der vereinfachten
Statusleiste (Signal/Batterie). Kleine Farbmanagement-Unterschiede bleiben auch
innerhalb der nativen Kartenfläche sichtbar. Dies ist keine Behauptung eines
vollständigen Pixelgleichstands oder eines aktuellen Runtime-Tests.

Die gespeicherte Sketch-Datei wurde geschlossen und erneut geöffnet; der neue
Frame und seine Komponenten wurden danach erneut über Sketch MCP geprüft.

## Konzeptänderung · gemeinsame Kartensteuerung

Auf weiteren Nutzerwunsch zeigt derselbe Frame jetzt eine vertikale Kapsel wie in
der zusätzlich gelieferten Apple-Maps-Referenz. Oben steht das native SF-Symbol
`target` für die Festival-Area, unten `location.fill` in Systemblau für den eigenen
Standort. Die Kapsel liegt bei x=334, y=670 pt, ist 48 × 96 pt groß und hat zwei
separate Bedienflächen von jeweils 48 × 48 pt. Ihr Abstand zur sichtbaren
Tab-Leiste beträgt etwa 24 pt. Die Standortfunktion ist ein Designkonzept;
der App-Code wurde nicht verändert.

`sketch-orte-concept@3x.png` dokumentiert den neuen Stand,
`concept-before-after.png` zeigt ihn rechts neben dem vorherigen Zustand und
`concept-rgb-difference.png` die unveränderten Positionen außerhalb der neuen
Kartensteuerung. Die vorherigen Vergleichsbilder bleiben als datierter
Codeabgleich erhalten. Symbolherkunft, Referenz und Prüfsummen stehen in
`../assets/orte/controls-manifest.json`.

## Korrektur · verknüpfte Apple-Liquid-Glass-Komponente

Die zunächst selbst gezeichnete Kapsel wurde auf Nutzerwunsch durch
`Toolbars/Light/Buttons/48pt/Active/Vertical Group - Symbol 2` aus dem mitgelieferten
**Apple iOS 27 UI Kit** ersetzt. Die Instanz ist mit der Bibliothek verknüpft und
wurde nicht abgelöst. Ihr originales Material verwendet einen aktivierten
Glass-Effekt mit Radius 6 sowie die originalen Füllungen, Schatten und Ecken.
Die beiden verschachtelten Symbol-Slots sind mit den vorhandenen nativen
SF-Symbolassets für `target` und `location.fill` belegt.

Die Komponente behält ihre native Größe von 48 × 110 pt und liegt bei x=334,
y=656 pt. Die Unterkante bleibt bei 766 pt und damit etwa 24 pt über der sichtbaren
Tab-Leiste. Die vorherige selbst gezeichnete Fläche wurde entfernt.

`sketch-orte-liquid-glass@3x.png`, `liquid-glass-before-after.png` und
`liquid-glass-rgb-difference.png` dokumentieren den neuen Stand und den Vergleich
zum vorherigen Konzept. Neben der neuen Kapsel und den geänderten Icon-Positionen
sind geringe Glyphen-Rasterunterschiede an bestehenden Tab-Labels sichtbar;
die Tab-Instanz wurde nicht bearbeitet und hat weiterhin keine Overrides.

## Abstände an die Karten-App-Referenz angepasst

Der aktuelle Stand in `sketch-orte-spacing@3x.png` verwendet die weiterhin
verknüpfte Apple-Komponente bei x=332, y=679 pt und **48 × 96 pt**. Der rechte Rand
beträgt 22 pt; zur sichtbaren Oberkante der Tab-Leiste bei y=791 bleiben 16 pt.
Die Icon-Canvas-Mittelpunkte liegen innerhalb der Kapsel bei (24, 24) und (24, 72),
also 48 pt auseinander. Die Größen und Randabstände orientieren sich an der
zusätzlichen Karten-App-Referenz. Die vertikale Position berücksichtigt die
abweichende Höhe der unteren App-Leiste.

Die Instanz erhält feste Abmessungen. Ihre lokalen verschachtelten Symbolquellen
gleichen den ursprünglichen Innenabstand der Apple-Toolbar aus; die SF-Symbolassets
liegen auf jeweils 28 × 28 pt großen transparenten Canvas-Flächen. Das originale
Liquid-Glass-Material und die Bibliotheksverknüpfung bleiben erhalten. Die
Symbolquellen und die gesamte Instanz wurden nicht abgelöst.

`spacing-before-after.png` und `spacing-rgb-difference.png` dokumentieren die
Korrektur gegenüber der unverkleinerten nativen Toolbar. Maße und Quellen sind in
`../assets/orte/controls-manifest.json` aktualisiert.

## Kartentypen · App und Sketch-Konzept

Die Übersicht enthält jetzt die native Apple-Toolbar-Gruppe
`Toolbars/Light/Buttons/44pt/Active/Horizontal Group - Symbol 2` mit Kartenoptionen
und Ortsliste. Beide Konzept-Frames verwenden eine gemeinsame lokale Symbol
Source mit der weiterhin verknüpften Apple-Komponente. Die SF-Symbolassets `map`
und `list.bullet` stammen aus `export_symbols.swift`.

Der neue Frame `D5F87450-5C40-40BE-BBC2-75EAF59B822E` zeigt das geöffnete Menü.
Es verwendet `Menus/Light/iPhone` aus dem **Apple iOS 27 UI Kit**, mit drei
editierbaren Optionen **Karte**, **Satellit** und **Hybrid**. Die aktuelle Auswahl
ist mit einem Häkchen markiert. Unbenötigte Beispielaktionen der nativen Komponente
sind per Instanz-Overrides ausgeblendet; keine Komponente wurde abgelöst.
Übersicht und Menüzustand stehen auf der Seite **Orte** nebeneinander, danach
folgen die unveränderte Nutzerreferenz und die aktualisierten Verhaltensnotizen.

Die App implementiert die drei nativen MapKit-Darstellungen und speichert die
Auswahl. Fünf gezielte Kameratestmethoden und drei Präferenztestmethoden bestanden.
Ein neuer visueller Runtime-Abgleich wurde nicht durchgeführt; die neue Toolbar
und das Menü orientieren sich an den nativen Kit-Vorgaben.

`sketch-orte-map-options@3x.png`, `sketch-orte-map-type-menu@3x.png` und
`map-type-concept-states.png` dokumentieren beide Konzeptzustände.
`map-options-rgb-difference.png` vergleicht die neue Übersicht mit dem vorherigen
Stand. Maße, Quellen, Auswahl und Prüfsummen stehen im Kontroll-Manifest.
