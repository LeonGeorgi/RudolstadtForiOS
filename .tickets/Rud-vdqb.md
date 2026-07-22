---
id: Rud-vdqb
status: in_progress
deps: []
links: [Rud-4h22, Rud-tuxh]
created: 2026-07-11T04:25:57Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [approved, design-audit, ios26, schedule, visual-design, information-hierarchy, effort-medium, confidence-high]
---
# Programm-Timeline: visuelle Ebenen und Spaltenhierarchie beruhigen

Die Timeline ist eine starke individuelle Lösung und soll erhalten bleiben. In der gerenderten Oberfläche konkurrieren jedoch mehrere horizontale Ebenen: Navigation und Tagessteuerung, Bühnenköpfe, Zeitachse, Eventflächen und die untere Dauerwarnung. Die Bühnenköpfe wirken durch eigene Hintergründe und Rundungen teilweise wie Dashboard-Cards. Gleichzeitig liegen mehrere blasse Eventfarben tonal nah beieinander, sodass Status, Kategorie und Auswahl nicht schnell genug unterscheidbar sind. Die angeschnittene nächste Bühne wirkt je nach Scrollposition eher zufällig als wie ein bewusster Hinweis auf horizontales Scrollen.

Betroffene Stellen:
- Shared/Screens/Schedule/ScheduleTimelineView.swift
- Shared/Screens/Schedule/ScheduleTimelineContentView.swift
- Shared/Screens/Schedule/ScheduleTimelineEventCell.swift
- Shared/Screens/Schedule/ScheduleScreen.swift

Dieses Ticket behandelt die visuelle Hierarchie bei normalen Schriftgrößen. Responsive Verhalten und Dynamic Type bleiben in Rud-4h22.

Priorität: mittel
Aufwand: mittel
Sicherheit: hoch

## Design

Die Timeline als eine zusammenhängende Arbeitsfläche komponieren:
- Bühnenköpfe typografisch und über Alignment gruppieren; ihre Card-Anmutung durch geringere Flächenbetonung und zurückhaltendere Rundung reduzieren
- Zeitachse als konstantes orientierendes Raster klar von den interaktiven Eventflächen unterscheiden
- Eventfarben auf eindeutige Rollen prüfen: Grundkategorie, gespeicherter Zustand und aktuelle Hervorhebung dürfen nicht nur aus mehreren ähnlich blassen Tönen bestehen
- Font-Weights reduzieren, wenn Bühnenname, Uhrzeit, Artist und Status gleichzeitig semibold erscheinen
- horizontalen Rand und Spaltenabstand so abstimmen, dass die nächste Bühne entweder bewusst als Scroll-Hinweis sichtbar ist oder sauber außerhalb liegt
- untere Warn-/Hinweisfläche visuell nachordnen und nicht als zusätzliche dauerhafte Hauptleiste inszenieren

Die iOS-26-Systemnavigation und vorhandene Tagessteuerung nicht mit zusätzlichen Materialien überlagern.

Nicht-Ziele:
- kein Ersatz der Timeline durch Cards oder eine reine Liste
- keine Änderung der Eventlogik oder Zeitberechnung
- keine zusätzliche Farbe pro Bühne
- keine Duplizierung der Accessibility-Arbeit aus Rud-4h22

## Acceptance Criteria

- Bühne, Zeit, Artist und gespeicherter Status besitzen eine eindeutig erkennbare Rangfolge.
- Bühnenköpfe wirken als Header des Rasters und nicht als Reihe separater Dashboard-Cards.
- Gespeicherte und nicht gespeicherte Events sind in Light und Dark Mode unterscheidbar, ohne dass die Fläche bunt oder unruhig wird.
- Die horizontale Scrollbarkeit ist verständlich; angeschnittene Spalten wirken bewusst und konsistent.
- Die Timeline bleibt auf normaler Textgröße kompakt und zeigt mindestens denselben Informationsumfang wie zuvor.
- Prüfung umfasst mehrere Tageszeiten, leere Zeiträume, überlappende Events sowie iPhone 17e und 17 Pro.
- Das bewährte Timeline-Konzept und Rud-tuxh bleiben gewahrt.

## Notes

**2026-07-22T00:48:12Z**

2026-07-22: Bühnenkopf-Konzept umgesetzt: separate secondarySystemBackground-Karten und Rundungen entfernt, Bühnenplaketten verkleinert, Namensgewicht reduziert und semantische, sehr dezente Separatoren zwischen den Bühnen durch die angehefteten Köpfe sowie den sichtbaren Timeline-Bereich geführt. Separatoren folgen horizontalem Scrollen und Spaltenzoom, liegen hinter den Events und bleiben schwächer als das Zeitraster. Geprüft: Swift-Parse und git diff --check. Ausstehend: visuelle Simulatorprüfung in Light/Dark, auf iPhone 17e/17 Pro sowie bei horizontalem Zoom; kein Build/App-Start autorisiert.

**2026-07-22T00:51:24Z**

2026-07-22: Raster nach Nutzerfeedback angeglichen: vertikale Bühnenseparatoren verwenden nun wie SwiftUI Divider exakt eine physische Pixelbreite über displayScale. Zusätzlich trennt eine fest angeheftete horizontale Divider-Linie direkt unter den Bühnennamen die Kopfzeile von der Timeline; die Zeitspalte bleibt ausgespart. Swift-Parse und git diff --check erfolgreich, visuelle Simulatorprüfung weiterhin ausstehend.

**2026-07-22T00:58:36Z**

2026-07-22: Linienimplementierung nach Review vereinfacht. displayScale-Berechnung entfernt; horizontales Zeitraster, vertikale Bühnenseparatoren und Header-Basislinie verwenden nun gemeinsam timelineGridLineThickness = 0.5 pt. Swift-Parse und git diff --check erfolgreich.

**2026-07-22T01:05:07Z**

2026-07-22: Nutzerbeobachtung bestätigt: frame(height:) änderte beim SwiftUI Divider nur den Layoutbereich, nicht dessen intern gezeichnete Haarlinie. Stärke auf 1 pt zurückgestellt und horizontales Zeitraster sowie Header-Basislinie auf explizit gezeichnete Rectangle-Linien umgestellt. Damit verwenden horizontale und vertikale Linien tatsächlich dieselbe 1-pt-Stärke und Farbe. Swift-Parse und git diff --check erfolgreich.

**2026-07-22T01:08:57Z**

2026-07-22: Rasterfarbe auf Apples semantische Separatorfarbe umgestellt (UIColor.separator auf iOS, NSColor.separatorColor auf macOS), ohne zusätzliche Opazität. Asymmetrischen Zellabstand korrigiert: Die 1-pt-Bühnentrenner lagen durch trailing-Overlay-Ausrichtung um eine halbe Linienstärke neben der Mitte. Separatoren werden nun in einem exakt columnSpacing-breiten Zwischenraum zentriert; bei 5 pt Abstand bleiben links und rechts jeweils 2 pt bis zur Linienkante. Swift-Parse und git diff --check erfolgreich.

**2026-07-22T01:21:10Z**

2026-07-22: Bühnenköpfe nach Nutzerfreigabe weiter nativisiert. Zeitplan verwendet nun eine lokale flache 18-pt-Nummernplakette mit direkter Bühnenfarbe, ohne Verlauf, Glanz, Kontur oder Schatten; globale StageNumber-Darstellung für Karte/Details bleibt unverändert. Bühnenname nutzt semantisches caption2 medium mit maximal zwei Zeilen, die Zahl caption2 semibold mit tabellarischen Ziffern. Kopfgeometrie zentral auf 60 pt reduziert und alle abhängigen Zeitachsen-, Event-, Zoomanker- und Jetzt-Linien-Offets synchronisiert. Vertikale Bühnenseparatoren beginnen erst unter der festen Header-Basislinie. Swift-Parse und git diff --check erfolgreich; visuelle Simulatorprüfung ausstehend.

**2026-07-22T01:23:25Z**

2026-07-22: Buildfehler nach Header-Änderung korrigiert. Ursache war die nicht existierende SwiftUI-Überladung frame(width:maxHeight:alignment:); der Breiten- und Höhenrahmen ist nun in zwei gültige frame-Modifier getrennt. Korrigierte Modifier-Kette zusätzlich isoliert mit SwiftUI typegecheckt; Datei-Parse und git diff --check erfolgreich. Vollständiger Projektbuild weiterhin nicht ausgeführt.

**2026-07-22T01:31:12Z**

2026-07-22: Auf Nutzerfeedback die vertikalen Bühnenseparatoren wieder durch die gesamte 60-pt-Kopfzeile bis nach oben geführt. Flache Plaketten, caption2-Typografie, symmetrische Zentrierung im Spaltenabstand und horizontale Basislinie bleiben erhalten. Swift-Parse und git diff --check erfolgreich.

**2026-07-22T01:34:42Z**

2026-07-22: Feste vertikale Separatorlinie an der rechten Kante der Zeitspalte ergänzt. Sie läuft durch Kopfzeile und sichtbare Timeline, bleibt unabhängig vom horizontalen Bühnen-Scrolloffset an der Zeitachse stehen und verwendet dieselbe semantische Separatorfarbe sowie 1-pt-Stärke. Swift-Parse und git diff --check erfolgreich.

**2026-07-22T01:37:53Z**

2026-07-22: Bewegte Außenkanten für das Bühnenraster ergänzt: Separator links vor Bühne 1 und rechts hinter der letzten Bühne laufen durch Header und Timeline mit dem horizontalen Bühnen-Scrolloffset. Die feste Zeitspaltenlinie liegt in Ruhe deckungsgleich mit der linken Rasterkante; beim Rubberband-Overscroll trennen sie sich, sodass sowohl Zeitspalte als auch verschobenes Bühnenraster abgeschlossen bleiben. Doppelte Event-Canvas-Zeichnung im Diff-Review entfernt. Swift-Parse und git diff --check erfolgreich.

**2026-07-22T01:40:40Z**

2026-07-22: Fehlende sichtbare bewegte linke Außenkante korrigiert. Ursache war die niedrige Rasterebene hinter der festen Zeitspalten-Abdeckung. Linke und rechte Bühnen-Außenseparatoren werden nun in einem eigenen zIndex-4.5-Overlay direkt aus timeWidth, columnSpacing, stageCount, columnWidth und beobachtetem horizontalOffset positioniert. Interne Separatoren bleiben im Rasterlayer; doppelte Außenlinien entfernt. GeometryReader/ViewBuilder isoliert typegecheckt, Datei-Parse und git diff --check erfolgreich.

**2026-07-22T01:43:58Z**

2026-07-22: Außenlinien ohne Sonderlayer neu eingebettet. Eigenen ScheduleTimelineStageBoundarySeparators-Overlay entfernt. ScheduleTimelineStageSeparators zeichnet nun alle Grenzen 0...stageCount einheitlich im selben Layer, mit identischer Farbe, Stärke, Geometrie, horizontalOffset- und Zeitspalten-Maskierungslogik; dieselbe Komponente wird für Header und Timeline verwendet. Dadurch scrollt die linke Außenkante nicht mehr über die Zeitbeschriftung. Refaktorierte SwiftUI-Struktur isoliert typegecheckt, Datei-Parse und git diff --check erfolgreich.

**2026-07-22T01:48:14Z**

2026-07-22: Zu großen Abstand zwischen Uhrzeiten und vertikaler Zeitspaltenlinie korrigiert. Ursache war zusätzliches 8-pt-Trailing-Padding an jeder Zeitbeschriftung. Padding entfernt; Uhrzeit endet nun an der 55-pt-Zeitspaltenkante, zur mittig im 5-pt-Rasterabstand liegenden Linie verbleiben nur die vorgesehenen 2,5 pt. Swift-Parse und git diff --check erfolgreich.

**2026-07-22T01:52:32Z**

2026-07-22: Zeitachse stärker an Apple Kalender angenähert. Gemeinsame timeColumnBoundaryWidth = timeWidth + columnSpacing/2 eingeführt und für feste Zeitspaltenmaske, Header-Basislinie sowie Beginn der Jetzt-Linie verwendet; horizontale Rasterlinien beginnen dadurch exakt am vertikalen Zeitseparator statt 2,5 pt davor. Zeitlabels nutzen nun semantisches caption, secondary-Farbe, tabellarische Ziffern und wieder 8 pt Abstand zur Linie. Halbstundenraster bleibt für Festivalnutzung erhalten. Swift-Parse und git diff --check erfolgreich; visuelle Simulatorprüfung ausstehend.

**2026-07-22T01:56:24Z**

2026-07-22: Bühnennamen werden im Header an der festen Zeitspaltengrenze durch eine Header-Maske abgeschnitten und können beim horizontalen Scrollen/Rubberbanding nicht mehr über die Uhrzeiten laufen. Die horizontale Trennlinie unter dem Bühnenkopf verläuft jetzt über die gesamte Breite einschließlich Zeitspalte; der feste vertikale Divider bleibt darüber sichtbar. Swift-Parsecheck und git diff --check erfolgreich, visuelle Simulatorprüfung steht noch aus.

**2026-07-22T02:08:38Z**

2026-07-22: Vertikale Bühnen-Separatoren reichen jetzt bis zum unteren Rand. Ursache war der als safeAreaInset eingebundene, schwebende Endzeiten-Hinweis, der die Timeline-Geometrie unten verkürzt hat; Hinweis auf bottom-aligned Overlay umgestellt, sodass der bestehende gemeinsame Separator-Layer ohne Sonderlinien die volle verfügbare Höhe erhält. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T02:09:19Z**

2026-07-22: Rundung der Timeline-Einträge an Apples Kalenderdarstellung angenähert: kontinuierlicher Eckenradius von 8 pt auf 4 pt reduziert; Rahmen, Innenabstände und Zustände unverändert. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T02:12:41Z**

2026-07-22: Zeitbeschriftungen auf die sichtbare Timeline-Geometrie begrenzt. Die außerhalb des Scrollviews fixierte Zeitskala erhält nun explizit die Viewport-Höhe und wird daran geclippt, sodass verschobene Uhrzeiten nicht mehr außerhalb des Inhalts über der Tab-Bar rendern. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T02:16:12Z**

2026-07-22: Vorheriges hartes Clipping der Uhrzeiten nach Nutzerfeedback entfernt. Zeitskala samt fester Zeitspaltenabdeckung in den eigentlichen ScrollView-Inhalt verlegt und nur horizontal gegen den Scrolloffset fixiert; vertikal scrollt sie nativ mit. Dadurch erhält sie automatisch denselben iOS-Scroll-Edge-Fade an der Tab-Bar wie Events, statt abrupt abgeschnitten zu werden. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T02:31:51Z**

2026-07-22: Temporären Live-Indikator-Demo-Modus ergänzt (klar markierter Schalter): Indikator animiert linear in 8 Sekunden wiederholt durch den sichtbaren Timeline-Viewport. Style an Apple Kalender angepasst: rote Capsule mit weißer monospaced Uhrzeit, direkt anschließende 2-pt-Systemrot-Linie. Reguläre Live-Positionsberechnung bleibt erhalten und greift nach Entfernen/Deaktivieren des Demo-Modus wieder. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T02:41:08Z**

2026-07-22: Live-Indikator-Demo verfeinert: Pillentext nutzt denselben rechten Textanker wie reguläre Uhrzeiten; Demo-Uhrzeit wird bei 30 Hz aus der animierten Position und dem aktuellen vertikalen Scrolloffset berechnet und zeigt damit die zum Raster passende Uhrzeit. Reguläre Zeitlabels werden anhand ihrer tatsächlichen geometrischen Überlappung mit der 18-pt-Pille temporär ausgeblendet. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T02:53:17Z**

2026-07-22: Live-Indikator-Demo an das Timeline-Koordinatensystem gebunden: Die animierte vertikale Position enthält jetzt denselben scrollState.verticalOffset wie Zeitlabels und Events. Dadurch bewegt sich Pille/Linie beim vertikalen Scrollen mit dem Raster; die daraus berechnete Demo-Uhrzeit bleibt weiterhin korrekt zur Inhaltsposition. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T03:02:09Z**

2026-07-22: Zoomstabilität der Live-Indikator-Demo korrigiert. Die Demo-Uhrzeit wird nicht mehr aus der aktuell gezoomten Punktstrecke zurückgerechnet, sondern animiert über eine feste, aus dem Default-Zoom abgeleitete Zeitspanne. Die Position wird anschließend aus dieser Uhrzeit mit dem aktuellen heightPerHour berechnet; Zoomen verschiebt den Indikator damit passend im Raster, ohne seinen Zeitwert zu verändern. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T03:12:00Z**

2026-07-22: Temporären Live-Indikator-Demo-Modus vollständig entfernt (TimelineView, Startzeit, feste Demo-Zeitspanne und Wiederholung). Beibehalten: Apple-artige rote Pille/Linie, gemeinsame Textausrichtung, Überdeckungs-Ausblendung, Scroll- und Zoomverankerung sowie minütliche Echtzeitaktualisierung. Reale Position nun per Date-Zeitdifferenz statt Stundenkomponenten berechnet, damit Festivalzeiten über Mitternacht korrekt funktionieren. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T03:16:54Z**

2026-07-22: Bühnenkopfzeile in den zweiachsigen Timeline-ScrollView integriert. Horizontal folgt sie jetzt nativ dem Scrollinhalt, sodass Drag-Gesten direkt auf Bühnenname/NavigationLink scrollen; vertikal wird nur der Scrolloffset kompensiert, damit der Header gepinnt bleibt. Header-Separatoren nutzen weiterhin dieselbe gemeinsame SeparatorGrid-Implementierung. Live-Indikator ebenfalls in den Scroll-Inhalt unter den Header verlegt: vertikal nativ verankert, horizontal kompensiert, damit Pille/Linie fixiert bleiben und korrekt vom Header überdeckt werden. Swift-Parsecheck und git diff --check erfolgreich; visuelle und Touch-Prüfung im Simulator steht aus.

**2026-07-22T03:24:05Z**

2026-07-22: Endzeiten-Hinweis aus der unteren schwebenden Capsule in die freie Kopfzelle links über der Zeitspalte verlegt. Neuer Auslöser ist ein einfacher info.circle-Button mit 44-pt-Touchfläche, Tint-Farbe sowie bestehendem Accessibility-Label/-Hint; Alert-Inhalt unverändert. Bottom-Overlay und nun ungenutzten ScheduleWarningStyle entfernt. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T03:28:55Z**

2026-07-22: Timeline-spezifischen oberen Scroll-Edge auf iOS 26 auf .hard gesetzt. Dadurch erhält der Zeitplan unter Navigation/Tagessteuerung eine nahezu opake lineare Grenze statt des automatischen weichen Unter-Toolbar-Scrollens. Modifier sitzt ausschließlich am ScheduleTimelineScrollView; ScheduleListView bleibt unverändert. Auf iOS <26 bleibt das bisherige Verhalten. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T03:31:38Z**

2026-07-22: Horizontale Zeitrasterlinien als Hintergrund des ScheduleTimelineEventCanvas in den zweiachsigen ScrollView verlegt. Separate äußere Grid-Ebene und manuelle verticalOffset-Synchronisierung entfernt. Linien liegen weiterhin hinter Events und fester Zeitspalte, erhalten nun aber denselben nativen Scroll-Edge-Fade an Tab-Bar und oberer harter Kante wie der übrige Scrollinhalt. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T03:41:16Z**

2026-07-22: Oberes Timeline-Underlap strukturell entfernt. Im Timeline-Modus ist der Tages-Picker nun ein reguläres festes VStack-Element oberhalb von ScheduleContentView statt safeAreaInset; der Timeline-Zweig wird zusätzlich an seinem tatsächlichen Rahmen geclippt. Dadurch beginnt/endet der ScrollView geometrisch unter Tages-Tabs und Navigation. Listenmodus behält den bisherigen daySwitcher als top safeAreaInset und bleibt ungeclippt. Vorherigen iOS-26-hard-ScrollEdge-Workaround entfernt. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T03:46:28Z**

2026-07-22: Vorherige geometrische Timeline-Begrenzung nach Nutzerfeedback zurückgenommen, da .clipped() und Tages-Picker als VStack-Geschwister den nativen Bottom-Bar-Underlap sowie die Reaktion des Tab-Bar-Accessories beeinträchtigten und einen Farb-Cut erzeugten. DaySwitcher wieder als safeAreaInset für beide Modi; im Timeline-Modus liegt dahinter systemBackground, sodass Scrollinhalt nicht durch die Tabs sichtbar ist. Timeline nutzt wieder nur den nativen iOS-26-hard-Top-ScrollEdge; unten bleibt sie ungeclippt und systemintegriert. Listenansicht erhält keinen zusätzlichen Hintergrund. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T03:51:09Z**

2026-07-22: Oberes Durchscheinen anhand Screenshot weiter korrigiert. Timeline-Zweig setzt nun exklusiv eine sichtbare systemBackground-Navigation-Bar; ScheduleScreen top safeAreaInset verwendet spacing 0 und weiterhin systemBackground hinter dem DaySwitcher. Den zusätzlichen .hard-ScrollEdge entfernt, um Farb-Cut zu vermeiden. Kein Clipping/Masking am ScrollView: unterer Tab-Bar-Underlap und Bottom-Accessory-Scrollreaktion bleiben nativ; Listenmodus erhält keine Toolbar-Background-Änderung. Swift-Parsecheck und git diff --check erfolgreich; visuelle Simulatorprüfung steht aus.

**2026-07-22T03:59:21Z**

2026-07-22: Verbliebenen schmalen Cut unter den Tages-Tabs als automatischen iOS-26-Top-Scroll-Edge-Effekt behandelt und ausschließlich an der Timeline über scrollEdgeEffectHidden(true, for: .top) deaktiviert; der native untere Fade bleibt aktiv. Für zuverlässige Reaktion von Tab-Bar und Bottom Accessory die kombinierte zweiachsige iOS-ScrollView in eine eindeutige vertikale Haupt-ScrollView mit verschachtelter horizontaler ScrollView aufgeteilt. Offset-/Größenzustand und Zoom-ScrollPosition werden pro Achse synchronisiert; Bühnen-Drag, gepinnte Kopf-/Zeitspalte und Zwei-Achsen-Zoom bleiben erhalten. Swift-Parsechecks für alle geänderten Schedule-Dateien und git diff --check erfolgreich; Touch-, Zoom- und Accessory-Verhalten im Simulator weiterhin visuell zu prüfen.

**2026-07-22T04:02:12Z**

2026-07-22: Den unmittelbar zuvor vorgenommenen Split in verschachtelte vertikale/horizontale ScrollViews nach Nutzerfeedback vollständig zurückgenommen. Die Timeline verwendet wieder eine einzige native ScrollView([.horizontal, .vertical]) und behält dadurch freies gleichzeitiges Panning auf beiden Achsen sowie die bestehende gemeinsame ScrollPosition für Zoom. Die Bottom-Accessory-Erkennung wird nicht zulasten dieser Kerninteraktion durch eine komplexere Scroll-Architektur erzwungen. Der separate Top-Scroll-Edge-Fix bleibt bestehen. Swift-Parsecheck und git diff --check erfolgreich.
