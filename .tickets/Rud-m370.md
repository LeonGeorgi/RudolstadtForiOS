---
id: Rud-m370
status: open
deps: []
links: [Rud-qf2n, Rud-tuxh]
created: 2026-07-11T04:25:57Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, friends, visual-design, composition, sections, effort-medium, confidence-high]
---
# Freunde-Screen: Card-Stapel reduzieren und Abschnittsrhythmus vereinheitlichen

Der Freunde-Screen verwendet für Profilhinweis, Status, Empfehlungen, leere Bereiche und weitere Inhalte wiederholt secondarySystemGroupedBackground mit eigener Rundung und Innenabstand. Funktional sind die Bereiche verständlich, visuell entsteht jedoch eine Folge ähnlich gewichteter weißer beziehungsweise heller Cards. Abschnittsüberschriften, Profilzeile und Empfehlungsshelf verwenden unterschiedliche Abstände und Textgewichte. Der unterste Container nähert sich der schwebenden Tab-Bar so stark, dass Content- und Systemebene miteinander kollidieren.

Betroffene Stellen:
- Shared/Screens/Friends/FriendsView.swift
- Shared/Screens/Friends/FriendsInsightRows.swift
- Shared/Screens/Friends/FriendsTogetherListView.swift
- Shared/Screens/Friends/SharedFestivalProfileDetailView.swift

Das Setup und die Reihenfolge deaktivierter Aktionen werden funktional in Rud-qf2n behandelt. Dieses Ticket gilt für die visuelle Komposition sowohl während als auch nach dem Setup.

Priorität: mittel
Aufwand: mittel
Sicherheit: hoch

## Design

Eine klarere vertikale Inhaltsstruktur herstellen:
- echte Sektionen primär über Überschrift, Abstand und Separator gruppieren
- Hintergrundcontainer nur dort behalten, wo eine zusammengehörige interaktive Einheit oder ein hervorgehobener Status sie rechtfertigt
- Informationshinweise, Profilstatus und Empfehlungen nicht alle mit demselben Card-Gewicht darstellen
- Abschnittsüberschriften auf konsistente Groß-/Kleinschreibung, Schriftrolle und linken Einzug bringen
- Profilzeile so ausbalancieren, dass Avatar, Name/Status und Aktion eine erkennbare Achse bilden
- Empfehlungsshelf als bewusst horizontalen Inhalt behandeln, ohne zusätzliche äußere Card um jede Ebene
- ausreichenden unteren Content-Abstand zur schwebenden iOS-26-Tab-Bar sicherstellen

Nicht-Ziele:
- keine Änderung des CloudKit-, QR- oder Sharing-Flows
- keine neue Card für jede Freundesperson
- keine dekorativen Schatten oder Gradients
- keine Duplizierung des Onboardings aus Rud-qf2n

## Acceptance Criteria

- Der Screen besitzt eine klare Reihenfolge aus Profil, Einrichtung beziehungsweise Status, Freunden und Empfehlungen.
- Nicht jeder Abschnitt benötigt einen eigenen gerundeten Hintergrund; verbleibende Container haben eine begründete Rolle.
- Überschriften, linke Achsen und vertikale Abstände sind konsistent.
- Leerer, teilweise eingerichteter und vollständig eingerichteter Zustand wirken jeweils bewusst komponiert.
- Der letzte Inhalt besitzt in allen Zuständen genügend Abstand zur Tab-Bar.
- Light und Dark Mode sowie kleiner und großer Bildschirm wurden geprüft.
- Umsetzung bleibt mit Rud-qf2n kompatibel.

