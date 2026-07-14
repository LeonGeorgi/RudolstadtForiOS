---
id: Rud-cu1x
status: closed
deps: []
links: []
created: 2026-07-12T16:55:42Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-sw5e
tags: [approved, accessibility, dynamic-type, artists, world-map-callout, effort-small, confidence-high]
---
# Künstlerübersicht: Weltkarten-Einstieg bei Accessibility-Größen vollständig lesbar machen

Der Weltkarten-Discovery-Einstieg kürzt Titel und Untertitel bei AX-XXXL stark. Der Befund wurde bei der visuellen Prüfung von Rud-3wiy/Rud-ygcc auf dem iPhone 17e sichtbar.

## Design

Den bestehenden kompakten Discovery-Charakter erhalten, bei Accessibility-Größen aber eine vertikale oder anderweitig robuste native Anordnung verwenden. Icon, Titel, Untertitel und Chevron dürfen sich nicht gegenseitig verdrängen.

## Acceptance Criteria

Titel und Untertitel sind bei AX-XXXL vollständig verständlich; das Touch-Ziel bleibt mindestens 44 Punkte hoch; normale Größen und die Weltkarten-Navigation bleiben unverändert; Light und Dark Mode sind geprüft.

## Notes

**2026-07-14T00:39:00Z**

Vorher auf iPhone 17e / iOS 26.5 bei AX-XXXL geprüft: Titel und Untertitel waren sichtbar zu Ellipsen gekürzt (/var/folders/5l/2600vsbn53zg45fssbbhv7ph0000gn/T/screenshot_optimized_42d0419c-1776-44d8-8172-36ffa45b4535.jpg). Callout für Accessibility-Größen auf vollständigen Umbruch, obere Ausrichtung, Text-Layout-Priorität und begrenzte Symbolskalierung umgestellt; normale Größen behalten die 48-Punkt-Einzeilen-Darstellung. Normal signierter Build erfolgreich. Maestro-Navigation zur Weltkarte erfolgreich. Light/AX-XXXL (/var/folders/5l/2600vsbn53zg45fssbbhv7ph0000gn/T/screenshot_optimized_33ec44ca-e947-475a-8628-f008a6216fb2.jpg), Dark/normal (/var/folders/5l/2600vsbn53zg45fssbbhv7ph0000gn/T/screenshot_optimized_e27391b2-0093-4396-b77e-a83607fde6a1.jpg) und Dark/AX-XXXL (/var/folders/5l/2600vsbn53zg45fssbbhv7ph0000gn/T/screenshot_optimized_db9f4b17-ddce-485b-ab42-4b588d1630ca.jpg) visuell geprüft. Simulator auf Light/normal zurückgestellt; git diff --check sauber.

**2026-07-14T00:40:03Z**

Zusatzprüfung Deutsch bei AX-XXXL erfolgreich: Titel und Untertitel vollständig sichtbar (/var/folders/5l/2600vsbn53zg45fssbbhv7ph0000gn/T/screenshot_optimized_429336cc-af24-4a51-8047-a3f3368e6d15.jpg). Simulator anschließend erneut ohne Sprach- oder Dynamic-Type-Override in Light Mode gestartet.
