---
id: Rud-r2ax
status: closed
deps: []
links: [Rud-tuxh]
created: 2026-07-11T04:21:04Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-lyze
tags: [approved, design-audit, ios26, artist-detail, visual-design, color-system, effort-medium, confidence-high]
---
# Künstlerdetail: Fotoabgeleitete Farbwelt als konsistentes Flächensystem definieren

Die aus dem Künstlerfoto abgeleitete Hintergrundfarbe ist eine der stärksten visuellen Eigenheiten der App. In den geprüften Beispielen reagiert sie überzeugend auf sehr verschiedene Motive: 5/8erl in neutralen dunklen Tönen, A Birchola in warmem Sand und Olive sowie Agnes Palmisano in Rosa beziehungsweise tiefem Grün im Dark Mode. Momentan werden die nachfolgenden Flächen jedoch überwiegend einzeln gestylt. Dadurch wirken Linkleiste, Eventblock, KI-Zusammenfassung, Beschreibung und Trennlinien nicht immer wie Teile desselben visuellen Systems.

Betroffene Stellen:
- Shared/Screens/Artist/Detail/ArtistDetailView.swift
- Shared/Screens/Artist/Detail/ArtistImageColorCache.swift
- Shared/Screens/Artist/Detail/ArtistDetailHeaderView.swift
- Shared/Screens/Artist/Detail/ArtistEventsBlock.swift
- Shared/Screens/Artist/Detail/ArtistDetailSections.swift
- Shared/Screens/Artist/Detail/ArtistDescriptionBlock.swift

Priorität: hoch
Aufwand: mittel
Sicherheit: hoch

## Design

Ein kleines, benanntes Set semantischer Artist-Detail-Tokens oder eine gleichwertige zentrale Theme-Struktur einführen. Mindestens vorsehen: Seitenhintergrund, Beschreibungshintergrund, Aktionsfläche, Eventfläche, Content-/KI-Fläche, Separator, Bildkontur und Schattenfarbe. Die Tokens müssen aus der vorhandenen fotoabgeleiteten Farbwelt hervorgehen und in Light und Dark Mode ausreichend differenziert bleiben.

Die vorhandene Extraktion und der Cache mit getrennten Light-/Dark-Farben sowie Kontrastkorrektur bleiben grundsätzlich erhalten. Ihre Algorithmen werden nur geändert, wenn konkrete Testbilder eine nachweisbare Schwäche zeigen.

Keine zusätzlichen Gradients, Glass-Flächen, Cards oder dekorativen Effekte einführen. Liquid Glass bleibt der System-Navigations- und Aktionsschicht vorbehalten. Inhaltliche Flächen sollen ruhig, farblich verwandt und klar unterscheidbar sein.

Nicht-Ziele:
- keine Änderung der Artist-Daten oder Bildquellen
- kein vollständiges Redesign der Detailseite
- keine Vereinheitlichung aller Künstler auf eine Markenfarbe
- keine Änderung von Accessibility-Semantik oder Interaktionslogik

## Acceptance Criteria

- Alle Artist-Detail-Unterbereiche beziehen ihre Farben, Konturen und Schatten aus einem nachvollziehbaren gemeinsamen Theme statt aus verstreuten Einzelwerten.
- Die individuelle Bildfarbe bleibt deutlich erkennbar und unterscheidet die Künstlerseiten weiterhin.
- Linkleiste, Eventblock, KI-Block und Beschreibung besitzen eine klare, aber zurückhaltende Hierarchie ohne Card-Stapel-Eindruck.
- Light und Dark Mode wurden mindestens mit 5/8erl, A Birchola und Agnes Palmisano geprüft.
- Sehr helle, sehr dunkle, warme und kühle Bildpaletten bleiben lesbar und wirken nicht schmutzig oder ausgewaschen.
- Die bestehenden Nicht-Regressionskriterien aus Rud-tuxh sind erfüllt.

## Notes

**2026-07-12T16:02:58Z**

Zentrales ArtistDetailTheme eingeführt und auf Seiten-/Beschreibungs-, Aktions-, Event- und Contentflächen sowie Separator, Bildkontur und Schatten angewendet. Simulator-Build erfolgreich. Mit Maestro auf iOS 26 visuell geprüft: 5/8erl, A Birchola und Agnes Palmisano in Light/Dark; Event- und Linkflächen nach Review kontrastreicher abgestimmt. Beim direkten Appearance-Wechsel trat ein CoreSimulator-Framebuffer-Artefakt im Remote-Bild auf; nach erneutem Betreten war das Bild korrekt. Keine Tests ausgeführt.
