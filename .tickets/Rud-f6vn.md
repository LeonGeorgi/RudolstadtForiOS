---
id: Rud-f6vn
status: closed
deps: []
links: []
created: 2026-07-11T03:11:28Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-sw5e
tags: [approved, design-audit, ios26, artists, dynamic-type, responsive-layout, effort-medium, confidence-high]
---
# Künstlerdetail bei Accessibility-Textgrößen responsiv umbauen

Bei AX-XXXL wächst der Künstlername stark, während Hero, Social-Links und Bewertung feste Geometrien behalten. Events und Beschreibung werden weit nach unten verdrängt.

## Design

Für Accessibility-Größen kompaktes Headerlayout verwenden: kleineres Hero, flexibel umbrechende Metadaten und adaptive Linkleiste. Aggressives Herunterskalieren von Text vermeiden.

## Acceptance Criteria

AX-XXXL zeigt Name, Metadaten und Aktionen ohne Überlagerung oder horizontales Abschneiden; mindestens ein Event oder ein klarer Inhaltsübergang ist mit normalem Scrollaufwand erreichbar; normale Größen behalten die aktuelle Bildwirkung.

## Notes

**2026-07-11T05:40:28Z**

Umgesetzt: Accessibility-Header mit kompaktem 16:9-Hero, vollständig umbrechendem Titel, adaptivem Linkraster und reduzierten festen Einzügen. Eventzeilen wechseln bei Accessibility-Größen auf ein vertikales Layout mit vollständigen Metadaten. Build & Run auf iPhone 17e / iOS 26.5 erfolgreich; normale Größe und AX-XXXL visuell per Screenshots geprüft.

**2026-07-11T06:10:38Z**

Visuelle Abschlussprüfung auf iPhone 17e / iOS 26.5 mit Maestro: normale Textgröße unverändert; AX-XXXL zeigt vollständigen Künstlernamen, Herkunft, Genre, Links und Bewertung ohne Überlagerung. Eventmetadaten und Zubehör wurden auf Accessibility 1 begrenzt; beide Auftritte sind nach kurzem Scroll vollständig lesbar und die Zeilen bleiben kompakt. Build & Run erfolgreich; lediglich zwei bestehende MapKit-Deprecation-Warnungen außerhalb des Ticketumfangs. Simulator anschließend auf normale Textgröße (medium) zurückgestellt. git diff --check erfolgreich.

**2026-07-11T06:14:01Z**

Nachbesserung der Link-Icons: LinkButton-Symbole verwenden nun eine feste 18-pt-Symbolschrift, damit SF Symbols bei AX-XXXL nicht innerhalb der festen 50-pt-Touchflächen überproportional wachsen. Auf iPhone 17e / iOS 26.5 bei AX-XXXL mit Maestro visuell geprüft; Iconreihe ist gleichmäßig, Build ohne Warnungen erfolgreich. Simulator wieder auf normale Textgröße (medium) gestellt. git diff --check erfolgreich.
