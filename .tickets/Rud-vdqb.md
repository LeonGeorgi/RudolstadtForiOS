---
id: Rud-vdqb
status: open
deps: []
links: [Rud-4h22, Rud-tuxh]
created: 2026-07-11T04:25:57Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, schedule, visual-design, information-hierarchy, effort-medium, confidence-high]
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

