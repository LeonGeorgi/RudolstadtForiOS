---
id: Rud-nyap
status: open
deps: []
links: [Rud-ckpo]
created: 2026-07-20T16:33:43Z
type: task
priority: 1
assignee: Leon Georgi
tags: [approved, performance, schedule]
---
# Schedule-Timeline: Bühnen mit LazyHStack rendern

Die Bühnen-Spalten eines Tages werden derzeit in einem normalen HStack vollständig aufgebaut. Bei großen Tagen sind dadurch alle Bühnen und Konzertkarten gleichzeitig Teil des View-Baums. Die horizontale Spaltenstruktur soll lazy geladen werden, sodass primär sichtbare und angrenzende Bühnen aufgebaut werden.

## Design

Den äußeren HStack des scrollbaren Timeline-Inhalts durch einen LazyHStack mit identischer Ausrichtung, Spaltenbreite und Spaltenabständen ersetzen. Die bestehende Gap-basierte vertikale Zeitpositionierung und die angehefteten Bühnenköpfe müssen erhalten bleiben. Eine zusätzliche vertikale Lazy-Struktur ist nicht Teil dieses Tickets, sofern sie nicht zwingend für korrektes Layout erforderlich ist.

## Acceptance Criteria

Bei Tagen mit vielen Bühnen werden nicht mehr alle Bühnen-Spalten sofort aufgebaut; dies wird mit gezielter Debug-Instrumentierung oder Instruments geprüft. Bühnenreihenfolge, Spaltenbreite, Abstände, Konzertpositionen und Gesamthöhe bleiben korrekt. Horizontales und vertikales Scrollen, Navigation, Kontextmenüs und Speichern funktionieren weiterhin. Kleine und leere Tage behalten ihr bisheriges Verhalten.

## Notes

**2026-07-21T14:28:32Z**

Implementiert: Der scrollbare Konzert-Canvas verwendet jetzt LazyHStack bei unveränderter Top-Ausrichtung, Spaltenbreite, Spaltenabständen, Zeitpositionierung und Mindestgröße. Der kleine angeheftete Bühnenkopf-HStack bleibt unverändert. Geprüft: iOS-18- und macOS-12.2-Syntaxparse sowie git diff --check. Ausstehend: Laufzeitprüfung der tatsächlich aufgebauten Bühnen mit Debug-Instrumentierung/Instruments und visuelle Simulatorprüfung (kein Build oder App-Start autorisiert).

**2026-07-21T14:32:38Z**

Regression nach erstem LazyHStack-Wechsel korrigiert: Der zweiachsige ScrollView erhält nun eine explizite Gesamtbreite aus Zeitspalte, Bühnenanzahl, Spaltenbreiten und Abständen sowie eine explizite Gesamthöhe aus dem längsten Bühnenablauf. Dadurch hängt die Scrollfläche nicht von noch nicht materialisierten Lazy-Spalten ab. Bühnen-Spalten besitzen eine feste Breite; Event-/Gap-Höhen verwenden dieselbe zentrale Berechnung für Layout und Content-Größe. iOS-/macOS-Parse und diff-check erfolgreich; Touch-/Simulatorprüfung weiterhin ausstehend.

**2026-07-21T14:33:52Z**

Auf Nutzerwunsch vollständig zurückgerollt: LazyHStack und die nachträgliche explizite Content-Größenberechnung brachten keine wahrnehmbare Verbesserung des Zoom-Ruckelns; die erste Variante verursachte zusätzlich eine Scroll-Regression. Der Konzert-Canvas verwendet wieder den vorherigen HStack und die ursprüngliche minWidth-/minHeight-Struktur. Ticket bleibt für einen anderen Ansatz offen.
