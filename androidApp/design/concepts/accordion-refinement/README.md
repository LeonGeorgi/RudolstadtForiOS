# H3 und H4 – erster Feinschliff

Diese Zwischenrunde zeigt zwei Ansätze für die Verbindung von R und Tastenseite
sowie einen geometrischen Neuaufbau der geöffneten Form H4.

- H3a: Das große R bildet die äußere Form der Tastenseite.
- H3b: Das R ist als Aussparung in ein vollständiges Gehäuse eingesetzt.
- H4a: Gehäuse und Balg teilen sich präzise Anschlusskanten; Knöpfe und Falten
  sind aus gemeinsamen Koordinaten und gleichmäßigen Abständen konstruiert.

`h4-details.png` enthält einen vergrößerten Vorher-/Nachher-Vergleich.
Die anschließende Runde in `../accordion-negative-space/` öffnet zusätzlich
die Fugen und Falten für bessere einfarbige Erkennbarkeit und entwickelt das
R aus getrennten Tastenformen weiter.

Die produktiven Icon-Ressourcen bleiben unverändert. Die SVG-Dateien sind
editierbar; Außenmasken und Systemfarben auf der Vergleichstafel sind simuliert.

Neu rendern mit Python 3, librsvg und ImageMagick:

```sh
python3 androidApp/design/concepts/accordion-refinement/generate.py
```
