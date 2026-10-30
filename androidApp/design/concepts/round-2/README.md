# Android-Icon – Runde 2

Diese Runde verzichtet auf Buchstabenkürzel. A ist als Bezugspunkt aus der ersten
Runde übernommen, G bis J sind neue Entwürfe. Die App-Ressourcen bleiben unverändert.

| Variante | Idee | Abwägung |
| --- | --- | --- |
| A · Original pur | Der vollständige weiße Schriftzug auf Violett | Engste Verbindung zum vorhandenen iOS-Icon. |
| G · Original zweifarbig | Der vollständige Originalschriftzug in Creme und warmem Orange auf dunklem Violett | Etwas mehr Festivalcharakter durch Farbe; gleiche Form wie A bei Systemfarben. |
| H · Akkordeon | Ein schräg gesetztes Akkordeon mit warmen Falten und hellen Enden | Direkter Musikbezug und charakteristische Silhouette; steht besonders für Folk. |
| I · Tanzpaar | Zwei Menschen in einer gemeinsamen Tanzbewegung | Vermittelt Tanz, Begegnung und Lebendigkeit; weniger konkreter Bezug zur Programm-App. |
| J · Programmklang | Ein gefaltetes Programmblatt mit ausgesparter Musiknote | Verbindet Programm und Musik; ähnelt eher einem allgemeinen Musikdokument. |

`vergleich.png` zeigt jeden Entwurf groß, in einer weiteren Außenform, als
Simulation mit Systemfarbe und bei 48 bzw. 64 px. Die Außenformen und Systemfarben
sind illustrative Vorschauen, keine Aufnahmen eines Android-Launchers.

Je Entwurf liegen eine editierbare SVG-Datei mit 108 × 108 Einheiten und eine
quadratische 1024-px-PNG-Ansicht des mittleren 72 × 72-Ausschnitts vor. Die
`*-monochrome.svg`-Dateien enthalten echte transparente Masken einschließlich
der Aussparungen. A und G verwenden die vorhandenen Originalkonturen;
H, I und J sind neue Vektorzeichnungen. Alle Hintergründe sind einfarbig.

Neu rendern, vom Projektstamm aus mit Python 3 und librsvg:

```sh
python3 androidApp/design/concepts/round-2/generate.py
```

Die Vergleichstafel wurde visuell geprüft. Vor einer finalen Übernahme folgen
der Export als Android-Drawable und eine Prüfung im laufenden Launcher.
