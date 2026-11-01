# Akkordeon – Entscheidungsbaum

Kleine, systematisch gegliederte Variationen des gemeinsamen K1/K3-Entwurfs.
Farben, Instrumentenbestandteile und die zwei iOS-Materialgruppen bleiben
unverändert. Jede Abzweigung verändert eine zusammenhängende Gestaltungsrichtung.

```text
0 · Bisheriger K1/K3-Hybrid
├── A · Ruhiger: weniger Neigung, Gehäuse auf gleicher Höhe
│   ├── A1 · Fein: schmalere Fugen, kleinere Aussparungen
│   └── A2 · Kräftig: breitere Fugen, größere Aussparungen
└── B · Bewegter: stärker geöffnet, asymmetrische Haltung
    ├── B1 · Fein: schmalere Fugen, kleinere Aussparungen
    └── B2 · Kräftig: breitere Fugen, größere Aussparungen
```

0 ist dieselbe Vektorvorlage wie der zuletzt gezeigte gemeinsame Entwurf.
A und B übernehmen dessen Detailstärken. Erst ihre Kinder ändern Fugenbreite,
Faltenschlitze, Tastenaussparungen und Knopflochgröße. Die Varianten werden auf
einen vergleichbaren Außenradius normalisiert.

## Dateien

- `entscheidungsbaum.png` / `.svg`: statische Übersicht aller Abzweigungen.
- `variants.json`: Bezeichnungen, Elternknoten und Gestaltungsparameter.
- Unterverzeichnisse `0`, `A`, `B`, `A1`, `A2`, `B1`, `B2`: gemeinsame Vektorvorlagen,
  echte Icon-Composer-Pakete und PNG-Vorschauen.
- `ios.png`: nativer 1024-px-Export von Icon Composer, iOS-Designgeneration 26.
- `ios-thumb.png`: nativer 192-px-Export; `ios-inline.png` ist dieselbe Ansicht
  mit 8 Bit je Kanal für die kompakte interaktive Vergleichsansicht.
- `android.png` und `mono.png`: simulierte runde Launcher- und Systemfarbenansicht.

Die interaktive Auswahl im Chat zeigt denselben Baum, vergleicht den gewählten
Knoten mit 0 und lässt zwischen Android, iOS und Android-Systemfarbe wechseln.
Sie ersetzt keine Auswahl oder Einbindung in das Produkt.

## Erzeugen und prüfen

Vom Projektstamm aus mit Swift, Python 3, librsvg und Icon Composer:

```sh
swift -module-cache-path /tmp/rudolstadt-swift-cache \
  androidApp/design/concepts/accordion-tree/generate.swift \
  "$PWD/androidApp/design/concepts/accordion-tree"
python3 androidApp/design/concepts/accordion-tree/render.py
```

Die statische Tafel wurde visuell geprüft. Zusätzlich geprüft wurden die
Vektoridentität des Ausgangsknotens, PNG-Abmessungen, die sicheren Motivgrenzen
und die Interaktionslogik der Auswahl mit einer lokalen DOM-Simulation.
Die direkte Browserprüfung lokaler Dateien wurde von der Browser-Richtlinie
blockiert; eine Prüfung im Browser oder laufenden Launcher wurde nicht durchgeführt.
Die produktiven Icons bleiben unverändert.
