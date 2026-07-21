---
id: Rud-i5zz
status: closed
deps: []
links: []
created: 2026-07-16T03:10:56Z
type: task
priority: 1
assignee: Leon Georgi
tags: [approved, accessibility, localization, ios26, artist-detail, friend-ratings, effort-small, confidence-high]
---
# Künstlerdetail: Bild- und Freundesbewertungs-Semantik korrigieren

Das tappbare Hero-Bild besitzt keine eindeutige zugängliche Aktionsbezeichnung. Die darüberliegende Freundesbewertung kann dadurch Teil des Bildbuttons werden, obwohl sie keine Bildaktion ist; ihre VoiceOver-Texte sind zudem hart auf Englisch codiert.

## Design

Den Bildbutton als Bildansicht-Aktion eindeutig benennen und die Freundesbewertung semantisch aus seinem Label lösen. Freundespräferenzen an einer inhaltlich passenden Stelle in Beziehung zur eigenen Bewertung präsentieren oder als getrenntes Accessibility-Element modellieren. Alle Mengen-, Bewertungs- und Fallbacktexte lokalisieren und vorhandene Profilnamen beibehalten. Keine Änderung am Sharing- oder Bewertungsmodell.

## Acceptance Criteria

VoiceOver kündigt das Hero-Bild mit Zweck und Aktion an; Freundesbewertungen werden getrennt, verständlich und in Deutsch wie Englisch vorgelesen; Symbolnamen werden nicht als technische Fallbacktexte ausgegeben; 1, 3 und mehr als 3 Freundesbewertungen sind verständlich; visuelle Darstellung bleibt bei fehlenden Freundesdaten unverändert stabil.

## Notes

**2026-07-20T08:43:23Z**

Kompaktes Direct-plus-Palette-Control umgesetzt: keine Bewertung und 1–3 Bewertungen direkt wählbar, alternative Marker im Menü, Freundesbewertungen neben der eigenen Bewertung statt im Hero-Bild. Bild- und Freundesbewertungs-Accessibility in Deutsch/Englisch lokalisiert; technische Symbolnamen erhalten einen generischen Fallback. Verifiziert mit swiftc -parse, plutil -lint und git diff --check. Build/Simulator- und visuelle Prüfung gemäß AGENTS.md nicht ohne ausdrückliche Autorisierung ausgeführt.

**2026-07-20T08:58:52Z**

Designiteration nach Screenshot: Reset, drei Direktbewertungen und Marker-Menü bilden nun ein einziges flaches 44-Punkte-Control. Separate Markerfläche, Trennlinie, weiße Auswahlkarte und Schatten entfernt; Auswahl wird semantisch getönt. Freundesbadges stehen als nachgestellter Status neben dem Control und fallen bei knapper Breite darunter. Swift-Parsing und git diff --check erfolgreich; kein Build/Simulatorlauf ohne ausdrückliche Autorisierung.

**2026-07-20T09:04:32Z**

Farb- und Formangleichung: Rating-Control nutzt nun dieselbe artistenspezifische theme.actionSurface wie die Social-Buttons. Äußere Form auf Capsule, ausgewählte Segmente und Marker auf Circle umgestellt; Interaktionslogik unverändert. Swift-Parsing und git diff --check erfolgreich; keine Build-/Simulatorprüfung ohne Autorisierung.

**2026-07-20T09:59:59Z**

Apple-nahe Gesamtiteration der Künstlerdetailseite umgesetzt: Hierarchie auf Identität, direkte Bewertung, Auftritte und danach externe Links umgestellt; 44-Punkte-Rating ohne Pseudo-Segmented-Control, kumulative Symbole, getrenntes Marker-Menü und größere Freundesindikatoren eingeführt. Ländernamen lokalisiert, 8:7 auch bei Accessibility-Größen beibehalten, native Toolbar vereinfacht, Oberflächenrollen reduziert, KI-Block beruhigt und Eventnavigation vom Bookmark getrennt. Verifiziert mit swiftc -parse, plutil -lint und git diff --check; kein Build oder Simulatorlauf ohne ausdrückliche Autorisierung.

**2026-07-20T10:30:22Z**

Simulatorprüfung auf iPhone 17 Pro mit iOS 26.5 abgeschlossen. Build & Run mit normaler Simulator-Signierung und -screenshotMode YES erfolgreich. Geprüft: Basislayout in Light/Dark Mode, Accessibility Large, 8:7-Hero, direkte 1–3-Bewertung, Alternativmenü, Reset, Accessibility-Werte/Auswahlzustände, Termin speichern/entfernen inklusive Bestätigung, Bühnennavigation, externe Website im Safari-Sheet, Notizeditor sowie Scrollbereich mit Direktlinks, KI-Zusammenfassung und Beschreibung. Im Accessibility-Large-Test wurde die inkonsistente Zentrierung des Ländernamens gefunden und auf durchgehend linksbündige Metadaten korrigiert; erneuter Build & Run erfolgreich. Simulatorzustand auf Large/Dark zurückgestellt. git diff --check erfolgreich.
