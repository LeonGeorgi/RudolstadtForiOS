# Akkordeon-Variationen für das Android-App-Icon

Weiterentwicklung des ausgewählten Entwurfs H aus Runde 2. Die produktiven
Launcher-Ressourcen bleiben unverändert.

| Entwurf | Gestaltung | Abwägung |
| --- | --- | --- |
| H1 · Ausgangspunkt | Die bisherige schräge Form mit warmem Balg und hellen Enden | Bewahrt den Entwurf, der zur weiteren Auswahl geführt hat. |
| H2 · Pur | Gerade, symmetrisch und einfarbig; weniger Bedienelemente | Besonders ruhig und klar als kleines Zeichen. |
| H3 · Mit Klaviatur | Drei breite Tastengruppen auf der linken Seite | Der Instrumentenbezug wird deutlicher, mit etwas mehr Detail. |
| H4 · Aufgezogen | Unterschiedlich geneigte Enden und ein aufgefächerter Balg | Bewegter, spielerischer und unregelmäßiger. |
| H5 · Konzertina | Polygonale Enden und eine kompaktere Silhouette | Verwandte Instrumentenidee mit einer anderen Außenform. |
| H6 · Warmer Klang | H1 mit orangefarbenen Enden, hellem Balg und dunklerem Violett | Eine Farbvariante; in Systemfarbe dieselbe Form wie H1. |

`vergleich.png` zeigt alle sechs Entwürfe in runder Form, mit einer zweiten
Außenform, als Vorschau mit Systemfarbe und bei 48 bzw. 64 px. Außenformen und
Systemfarben sind simuliert. Es sind keine Aufnahmen eines Android-Launchers.

Jeder Entwurf liegt als SVG mit 108 × 108 Einheiten und als quadratische
1024-px-PNG-Ansicht des mittleren 72 × 72-Ausschnitts vor. Die zugehörige
`*-monochrome.svg` ist eine echte transparente Maske mit ausgesparten Details.
Die Zeichnungen wurden einheitlich innerhalb eines Kreises mit etwa 32 dp
Radius zentriert; damit bleibt Reserve innerhalb der sicheren 66-dp-Zone.

Alle Hintergründe sind einfarbig. Violett verbindet die Vorschläge mit dem
iOS-Icon; Creme und Orange sind zusätzliche gestalterische Akzente.

Neu rendern, vom Projektstamm aus mit Python 3, librsvg und ImageMagick:

```sh
python3 androidApp/design/concepts/accordion-studies/generate.py
```

Geprüft wurden die gerenderte Vergleichstafel, die Exportabmessungen und die
Silhouetten der monochromen Masken im sicheren Innenbereich. Nach einer Auswahl
folgen die Übertragung in Android-Drawables und die Prüfung im Launcher.
