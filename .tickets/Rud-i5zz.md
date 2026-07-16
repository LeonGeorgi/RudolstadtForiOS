---
id: Rud-i5zz
status: open
deps: []
links: []
created: 2026-07-16T03:10:56Z
type: task
priority: 1
assignee: Leon Georgi
tags: [needs-approval, accessibility, localization, ios26, artist-detail, friend-ratings, effort-small, confidence-high]
---
# Künstlerdetail: Bild- und Freundesbewertungs-Semantik korrigieren

Das tappbare Hero-Bild besitzt keine eindeutige zugängliche Aktionsbezeichnung. Die darüberliegende Freundesbewertung kann dadurch Teil des Bildbuttons werden, obwohl sie keine Bildaktion ist; ihre VoiceOver-Texte sind zudem hart auf Englisch codiert.

## Design

Den Bildbutton als Bildansicht-Aktion eindeutig benennen und die Freundesbewertung semantisch aus seinem Label lösen. Freundespräferenzen an einer inhaltlich passenden Stelle in Beziehung zur eigenen Bewertung präsentieren oder als getrenntes Accessibility-Element modellieren. Alle Mengen-, Bewertungs- und Fallbacktexte lokalisieren und vorhandene Profilnamen beibehalten. Keine Änderung am Sharing- oder Bewertungsmodell.

## Acceptance Criteria

VoiceOver kündigt das Hero-Bild mit Zweck und Aktion an; Freundesbewertungen werden getrennt, verständlich und in Deutsch wie Englisch vorgelesen; Symbolnamen werden nicht als technische Fallbacktexte ausgegeben; 1, 3 und mehr als 3 Freundesbewertungen sind verständlich; visuelle Darstellung bleibt bei fehlenden Freundesdaten unverändert stabil.
