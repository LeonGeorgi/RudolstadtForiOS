---
id: Rud-tn1g
status: open
deps: []
links: []
created: 2026-07-22T04:04:50Z
type: bug
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, ios26, schedule, visual-design]
---
# Oberen Scroll-Edge-Cut im Zeitplan beseitigen

Im Timeline-Modus bleibt direkt unter der Tagesauswahl eine schmale horizontale Farb- bzw. Effektkante sichtbar. Der bisherige timeline-lokale Versuch mit scrollEdgeEffectHidden(true, for: .top) entfernt sie nicht vollständig. Die Darstellung soll ohne sichtbaren Cut in den festen Bühnen-Header übergehen, während der Zeitplan weiterhin nicht hinter Tages-Tabs oder Navigation sichtbar wird.

## Design

Ursache in der Kombination aus safeAreaInset-Tagesauswahl, Liquid-Glass-/Scroll-Edge-Effekt, Navigation-Bar-Hintergrund und Timeline-ScrollView isolieren. Keine Masken oder Clipping-Lösungen verwenden, die freien zweiachsigen Scroll, den nativen unteren Fade oder die Reaktion von Tab Bar und Bottom Accessory beeinträchtigen. Listenansicht unverändert lassen.

## Acceptance Criteria

Im Timeline-Modus ist bei Ruhe, vertikalem Scrollen und Rubberbanding keine schmale Farb- oder Schattenkante unter der Tagesauswahl sichtbar. Inhalt erscheint nicht hinter Tages-Tabs oder Navigation. Freies gleichzeitiges zweiachsiges Scrollen, Zoom, unterer nativer Fade und Bottom-Accessory-Verhalten bleiben unverändert. Listenansicht zeigt keine Regression. Visuell auf mindestens einem iPhone mit iOS 26 in Light und Dark Mode geprüft.
