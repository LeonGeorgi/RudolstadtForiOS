---
id: Rud-bjgb
status: closed
deps: []
links: []
created: 2026-07-16T03:10:56Z
type: task
priority: 2
assignee: Leon Georgi
tags: [approved, design-audit, ios26, artist-detail, visual-design, adaptive-layout, ipad, effort-medium, confidence-high]
---
# Künstlerdetail: Gesamtkomposition und Regular-Width-Layout abstimmen

Die bestehenden Künstlerdetail-Tickets verfeinern einzelne Bausteine, definieren aber keine gemeinsame Inhaltsbreite, Abschnittsreihenfolge und Rhythmus für die Seite als Ganzes. Auf Regular Width läuft die Komposition nahezu über die gesamte Breite; auf dem iPhone konkurrieren mehrere Aktionslagen, bevor die Auftritte beginnen.

## Design

Eine gemeinsame adaptive Layout-Hülle für Hero, Metadaten, Aktionen, Auftritte, Notiz und Langtext definieren. Standardränder und eine angemessene maximale Inhalts- beziehungsweise Lesebreite verwenden; Hero und fotoabgeleitete Identität erhalten. Auftritte als primären handlungsrelevanten Inhalt priorisieren, Notiz und Langtext logisch nachordnen. Keine zusätzlichen Cards, Glass-Flächen oder dekorativen Effekte. Die Detailverbesserungen Rud-7hbl, Rud-e70l, Rud-t6ld und Rud-itvk darin koordinieren, ohne deren Verantwortlichkeiten zu duplizieren.

## Acceptance Criteria

Die Seite besitzt auf iPhone und iPad eine erkennbare durchgehende Achse und konsistenten vertikalen Rhythmus; Textzeilen werden auf Regular Width nicht übermäßig lang; Hero bleibt der visuelle Fokus; Links und Bewertung bilden eine sekundäre Aktionszone; Auftritte sind mit normalem Scrollaufwand erreichbar; Notiz, KI-Zusammenfassung und Beschreibung folgen in nachvollziehbarer Priorität. Prüfung umfasst iPhone 17e und 17 Pro, iPad in Portrait und Landscape, Light/Dark sowie normale und Accessibility-Schrift.

## Notes

**2026-07-16T04:13:54Z**

Umgesetzt in ArtistDetailView.swift: gemeinsame adaptive 720-pt-Inhaltsachse, 16/24-pt-Außenränder, kompaktere sekundäre Aktionszone und Reihenfolge Hero → Aktionen → Auftritte → Notiz → KI-Zusammenfassung → Beschreibung. Verifiziert mit erfolgreichem iOS-Simulator-Build sowie visuell auf iPhone 17e, iPhone 17 Pro und iPad Pro 13 Zoll in Portrait/Landscape, Light/Dark und normaler/Accessibility-Large-Schrift. Detailgestaltung aus Rud-7hbl, Rud-e70l, Rud-t6ld und Rud-itvk bewusst nicht dupliziert.
