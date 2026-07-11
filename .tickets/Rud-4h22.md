---
id: Rud-4h22
status: closed
deps: []
links: [Rud-vdqb, Rud-tuxh]
created: 2026-07-11T03:11:28Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-sw5e
tags: [approved, design-audit, ios26, schedule, dynamic-type, responsive-layout, effort-large, confidence-high]
---
# Programm-Timeline für Dynamic Type und kleine Geräte adaptieren

Timeline-Geometrie und Texte verwenden feste Maße bis hinunter zu 7 Punkt. Bei AX-XXXL bleibt der Zeitplan klein, während die Endzeitwarnung stark skaliert, abgeschnitten wird und Inhalt verdeckt.

## Design

Semantische Textstile und ScaledMetric einsetzen. Bei Accessibility-Größen die Listenansicht als zugänglichen Standard verwenden oder eine gleichwertig adaptive Timeline anbieten. Dauerwarnung kompakter und nicht verdeckend präsentieren.

## Acceptance Criteria

Bei AX-XXXL sind Zeiten, Bühnen und Events lesbar; Warntext ist vollständig zugänglich und verdeckt keinen Inhalt; iPhone 17e zeigt einen nutzbaren Flow; Timeline-Konzept bleibt bei normalen Größen erhalten.

## Notes

**2026-07-11T05:50:53Z**

Implementiert: Bei Accessibility-Dynamic-Type wird die vorhandene Listenansicht effektiv erzwungen, ohne die gespeicherte Nutzerwahl zu überschreiben; der Modus-Schalter wird dann ausgeblendet. Listenzeilen wechseln auf ein umbrechendes vertikales AX-Layout. Der bisher überlagernde Endzeit-Hinweis ist nun ein kompakter Inline-Button mit vollständig zugänglichem Systemdialog. Lokalisierungen DE/EN ergänzt. git diff --check ist sauber; Build und Simulator-QA gemäß AGENTS.md nicht ohne ausdrücklichen Auftrag ausgeführt.

**2026-07-11T06:26:25Z**

Visuelle Abnahme auf verbundenem iPhone-17e-Simulator (iOS 26.5) mit Maestro abgeschlossen. Normale Timeline und kompakter Inline-Hinweis bestätigt. Hinweisdialog zeigt Titel, vollständigen Warntext und OK ohne Überlagerung. Start mit -screenshotMode YES und AX-XXXL: automatische Listenansicht aktiv, Timeline-/Listen-Schalter ausgeblendet; Eventnamen, Uhrzeiten und Bühnen umbrechen vollständig, keine horizontalen Abschneidungen oder unzugänglichen Überlagerungen, sinnvoll scrollbar. Screenshots: /tmp/rud-4h22-normal-timeline.png, /tmp/rud-4h22-estimated-end-times-dialog.png, /tmp/rud-4h22-ax-xxxl-list.png. Keine Codekorrektur und kein Neubau erforderlich.

**2026-07-11T06:33:20Z**

Gestalterische Nachbesserung umgesetzt: dekorative Glass-/Material-Kapsel des Endzeit-Hinweises entfernt. Stattdessen ruhige native 44-Punkt-Hinweiszeile mit Akzent-Info-Icon, sekundärem Text, Trennlinie und lokalisiertem Accessibility-Hint. git diff --check ist sauber. Ticket bleibt bis zur visuellen Prüfung eines neu gebauten Simulator-Builds in progress.

**2026-07-11T06:36:56Z**

Neuen Build mit normaler lokaler Signierung auf iPhone 17e (iOS 26.5) gebaut und mit -screenshotMode YES gestartet. Maestro-Screenshot visuell geprüft: Hinweis ist nun eine ruhige, native Informationszeile ohne Glass-/Kartenfläche; Akzent-Icon, sekundärer Text, 44-Punkt-Tap-Ziel und Trennlinie ergeben eine klare Hierarchie zur Timeline. Tap und vollständiger Systemdialog erneut verifiziert. Screenshots: /tmp/rud-4h22-refined-end-time-notice.png und /tmp/rud-4h22-refined-end-time-dialog.png. Build erfolgreich; nur zwei bereits bestehende MapKit-Deprecation-Warnungen.

**2026-07-11T06:42:00Z**

Zweite visuelle Iteration nach Screenshot-Review: Divider entfernt und Hinweis von sichtbarer 44-Punkt-Zeile auf kompakte Caption-Metainformation reduziert; sechs Punkte Abstand zu den Bühnenköpfen, keine Karte/Materialfläche. Erneut gebaut und auf iPhone 17e (iOS 26.5) mit Maestro geprüft. Screenshot /tmp/rud-4h22-compact-end-time-notice.png zeigt eine deutlich geschlossenere Hierarchie ohne kollidierenden Separator oder übermäßigen Leerblock. Hinweis und Dialog bleiben semantisch antippbar/funktionsfähig. git diff --check sauber.

**2026-07-11T06:47:19Z**

Auf Nutzerpräferenz wieder als untere Glass-Box umgesetzt, diesmal kompakt und inhaltsbreit. Der Hinweis sitzt per safeAreaInset über der Tabbar, verdeckt keine Timeline-Inhalte und konkurriert nicht mit Tagesauswahl/Bühnenköpfen. Build auf iPhone 17e iOS 26.5 erfolgreich; Screenshot visuell geprüft: /tmp/rud-4h22-bottom-glass-notice.png. Ticket bleibt bis zur Nutzerfreigabe in progress.

**2026-07-11T06:58:34Z**

AX-XXXL-Listendesign überarbeitet und in zwei Screenshot-Iterationen geprüft. Accessibility-Zellen erhalten 16-Punkt-Listenränder, getrennte Hierarchie für Tag/Event/Uhrzeit/Bühne, 96x84-Künstlerbild, normal großes Bookmark-Symbol bei erhaltenem Tap-Ziel und max. AX-XXL nur innerhalb der informationsreichen Eventzelle; Navigation/System bleiben AX-XXXL. Kurze und lange Inhalte mit Maestro geprüft. Screenshots: /tmp/rud-4h22-ax-list-refined-top.png und /tmp/rud-4h22-ax-list-refined-long-content.png. Build erfolgreich, git diff --check sauber. Ticket bleibt zur visuellen Nutzerfreigabe in progress.

**2026-07-11T07:03:52Z**

Regression in normaler Listenansicht behoben: feste Bookmark-Symbolgröße war versehentlich im gemeinsamen Zubehörpfad aktiv und ist nun strikt auf Accessibility-Größen begrenzt. Neu gebaut und beide Zustände visuell geprüft. Normale Liste wieder im ursprünglichen kompakten Layout: /tmp/rud-4h22-normal-list-regression-check.png. AX-Layout unverändert verbessert: /tmp/rud-4h22-ax-list-after-regression-fix.png. git diff --check sauber.

**2026-07-11T07:07:51Z**

Gemeinsame Zellensprache überarbeitet: Standardzellen jetzt mit 16-Punkt-Rändern, 64x64-Bild mit 8-Punkt-Rundung, 8-Punkt-Vertikalabstand, klarer Hierarchie aus Tag/Headline/Uhrzeit+Bühne und sekundärer Bühnenfarbe ohne Klammerkonstrukt. AX übernimmt konsistente Bildrundung; eigenes Layout bleibt erhalten. Beide Zustände nach Build visuell geprüft: /tmp/rud-4h22-normal-list-redesign.png und /tmp/rud-4h22-ax-list-after-cell-redesign.png. git diff --check sauber.

**2026-07-11T07:12:22Z**

Normale Liste auf Nutzerwunsch leicht vertikal verdichtet: Bilder 60x60 statt 64x64, Standard-Zellenränder vertikal 6 statt 8 Punkte. AX-Ränder und AX-Bildgrößen unverändert. Nach neuem Build beide Zustände visuell geprüft: /tmp/rud-4h22-normal-list-compact.png und /tmp/rud-4h22-ax-list-after-normal-compaction.png. git diff --check sauber.

**2026-07-11T07:19:57Z**

Lange Bühnennamen in normaler Liste verbessert: Bühnenlabel darf bis 85 % typografisch verdichten und erhält Layout-Priorität; Uhrzeit ist zugleich als unteilbare feste Einheit mit höherer Priorität geschützt. Erste Iteration zeigte im Screenshot vertikal zerfallende Uhrzeiten und wurde verworfen/korrigiert. Finaler Build zeigt u. a. Concert Stage Heinepark vollständig: /tmp/rud-4h22-normal-list-full-stage-names-fixed.png. AX-Pfad unverändert. git diff --check sauber.

**2026-07-11T07:44:12Z**

Listen-Zubehör in normaler Textgröße visuell auf iPhone 17e (iOS 26.5) nachjustiert: kompakte Rating-Glyphe, überlappende Freund:innen-Badges und Bookmark mit erhaltener 44-pt-Touchfläche; sichtbare Abstände Herz–Freund:innen–Bookmark ausgeglichen und Leerraum vor dem Disclosure-Chevron reduziert. Screenshot-Modus enthält dafür Ratings/Freund:innen auf dem ersten Tag. Finaler Screenshot: /var/folders/5l/2600vsbn53zg45fssbbhv7ph0000gn/T/screenshot_optimized_74cbbfed-05ff-4ea9-a618-fdce802c3364.jpg. Big Stage Heinepark, Concert Stage Heinepark und Bauernhäuser sind vollständig sichtbar. Build normal signiert erfolgreich. Ticket bleibt bis zum visuellen Nutzer-Okay in progress.

**2026-07-11T08:12:46Z**

Finale Nutzerfreigabe nach iterativer visueller QA auf iPhone 17e (iOS 26.5): normale Liste mit Uhrzeit+Tag über Künstlername, unskalierter Bühne über voller Breite und ausgewogener Rating/Freund:innen/Bookmark-Gruppe; AX-XXXL erzwingt weiterhin Listenansicht und blendet den Modusschalter aus. AX-Zubehör abschließend proportional vergrößert (Rating 1,3x, Freund:innen 1,25x, Bookmark 24 pt), ohne Überlagerungen. Finaler AX-Screenshot: /var/folders/5l/2600vsbn53zg45fssbbhv7ph0000gn/T/screenshot_optimized_8cd002f2-e57f-49f9-9738-36302e31dc00.jpg. Normal signierter Simulator-Build erfolgreich; git diff --check sauber. Acceptance Criteria erfüllt und Nutzer hat Commit/Schließen angewiesen.
