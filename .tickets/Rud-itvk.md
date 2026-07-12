---
id: Rud-itvk
status: open
deps: [Rud-r2ax]
links: [Rud-tuxh]
created: 2026-07-11T04:21:05Z
type: task
priority: 3
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, artist-detail, visual-design, ai-summary, description, effort-small, confidence-medium]
---
# Künstlerdetail: Übergang zwischen KI-Zusammenfassung und Beschreibung harmonisieren

Unterhalb der Auftritte wechseln fotoabgeleiteter Seitenhintergrund, materialartige KI-Zusammenfassung und die separate Beschreibungsfläche relativ abrupt. Der KI-Block besitzt zusätzlich eine farbige Headline, Kontur und Schatten, während die Beschreibung bewusst schlicht ist. Jedes Element funktioniert für sich, zusammen entsteht je nach Künstlerpalette jedoch ein unsteter Abschluss der Seite.

Betroffene Stellen:
- Shared/Screens/Artist/Detail/ArtistDetailView.swift für die Abschnittsreihenfolge und Hintergründe
- Shared/Screens/Artist/Detail/ArtistAISummaryBlock.swift
- Shared/Screens/Artist/Detail/ArtistDetailSections.swift
- Shared/Screens/Artist/Detail/ArtistDescriptionBlock.swift

Priorität: niedrig
Aufwand: klein
Sicherheit: mittel, da nicht jeder geprüfte Künstler denselben KI-Inhaltszustand zeigte

## Design

Den unteren Seitenabschluss als bewusste Folge aus Zusammenfassung und Langtext abstimmen:
- KI-Fläche, Kontur und Schatten an das zentrale Artist-Detail-Theme anbinden
- prüfen, ob der aktuelle Materialeinsatz bei jeder Künstlerfarbe nötig ist oder eine ruhigere thematische Inhaltsfläche besser trennt
- Radius, Konturstärke und Schatten so reduzieren, dass der KI-Block nicht stärker als Hero oder Events wirkt
- Lesbarkeit und visuelles Gewicht der farbigen KI-Headline auf warmen, kühlen, hellen und dunklen Paletten prüfen
- Übergang zur descriptionBackground-Fläche über konsistente Abstände und verwandte Farbwerte beruhigen
- Beschreibung weiterhin als ruhigen Fließtext ohne zusätzliche Card belassen

Nicht-Ziele:
- keine neue KI-Funktion oder Änderung des Textinhalts
- keine Card um die Künstlerbeschreibung
- kein zusätzlicher Gradient oder Glass-Layer
- keine Änderung der Abschnittsreihenfolge ohne konkreten visuellen Grund

## Acceptance Criteria

- KI-Zusammenfassung und Beschreibung bilden einen ruhigen, klar gegliederten Seitenabschluss.
- Der KI-Block konkurriert nicht mit Hero-Foto, Titel oder Auftritten.
- Die farbige Headline bleibt auf allen geprüften Paletten lesbar und wirkt nicht losgelöst von der Künstlerfarbwelt.
- Seiten mit und ohne KI-Zusammenfassung besitzen einen stimmigen vertikalen Rhythmus.
- Beschreibung bleibt eine schlichte, gut lesbare Textfläche ohne zusätzliche Card.
- Prüfung umfasst 5/8erl, A Birchola und Agnes Palmisano sowie Light und Dark Mode, soweit KI-Inhalte verfügbar sind.
