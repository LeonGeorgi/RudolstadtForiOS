---
id: Rud-nyap
status: open
deps: []
links: [Rud-ckpo]
created: 2026-07-20T16:33:43Z
type: task
priority: 1
assignee: Leon Georgi
tags: [needs-approval, performance, schedule]
---
# Schedule-Timeline: Bühnen mit LazyHStack rendern

Die Bühnen-Spalten eines Tages werden derzeit in einem normalen HStack vollständig aufgebaut. Bei großen Tagen sind dadurch alle Bühnen und Konzertkarten gleichzeitig Teil des View-Baums. Die horizontale Spaltenstruktur soll lazy geladen werden, sodass primär sichtbare und angrenzende Bühnen aufgebaut werden.

## Design

Den äußeren HStack des scrollbaren Timeline-Inhalts durch einen LazyHStack mit identischer Ausrichtung, Spaltenbreite und Spaltenabständen ersetzen. Die bestehende Gap-basierte vertikale Zeitpositionierung und die angehefteten Bühnenköpfe müssen erhalten bleiben. Eine zusätzliche vertikale Lazy-Struktur ist nicht Teil dieses Tickets, sofern sie nicht zwingend für korrektes Layout erforderlich ist.

## Acceptance Criteria

Bei Tagen mit vielen Bühnen werden nicht mehr alle Bühnen-Spalten sofort aufgebaut; dies wird mit gezielter Debug-Instrumentierung oder Instruments geprüft. Bühnenreihenfolge, Spaltenbreite, Abstände, Konzertpositionen und Gesamthöhe bleiben korrekt. Horizontales und vertikales Scrollen, Navigation, Kontextmenüs und Speichern funktionieren weiterhin. Kleine und leere Tage behalten ihr bisheriges Verhalten.
