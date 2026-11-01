# Akkordeon – Fugen, Falten und Systemfarben

Diese Runde entwickelt H3 und H4 mit Fokus auf die einfarbige Erkennbarkeit weiter.
Alle dunklen Details sind echte transparente Aussparungen. Gehäuse und Balg
werden durch bewusste Fugen getrennt; bei K2 bis K6 sind zusätzlich die
Balgfalten durchgehender geöffnet. Die produktiven Icon-Ressourcen bleiben unverändert.

| Variante | Idee |
| --- | --- |
| K1 · Mit Gehäusefugen | H4 mit getrennten Gehäusen und geschlossen endenden Faltenschlitzen. |
| K2 · Offene Falten | Die beiden Faltenschlitze gehen bis an den Rand und trennen die drei Balgsegmente. |
| K3 · Klaviatur im Schwung | K2 mit einer deutlich ausgeschnittenen Tastenseite. |
| K4 · R aus Tasten | Das große R entsteht aus getrennten Tastenformen; kein aufgedruckter Buchstabe. |
| K5 · Konzertina | Offener Balg mit polygonalen Enden und wenigen Knöpfen. |
| K6 · Balg pur | Breitere Faltenabstände und nur zwei Bedienelemente je Seite. |

Die geöffneten Formen verwenden dieselben lokalen Koordinaten für Gehäuse,
Anschlusskanten, Knöpfe und Tastenaussparungen. Die Falten werden zwischen den
Anschlusskanten interpoliert; Fugen liegen auf den gemeinsamen Kanten. So werden
unbeabsichtigte Überschneidungen durch kontrollierte Zwischenräume ersetzt.

`vergleich.png` zeigt Farb- und Systemfarbenvorschau gleich groß sowie beide
Versionen bei 48 und 64 px. Die Systemfarben und Masken sind simuliert.

Je Entwurf liegen eine editierbare 108 × 108-SVG, eine 1024-px-PNG-Ansicht des
mittleren 72 × 72-Ausschnitts und eine transparente `*-monochrome.svg` vor.
Die Masken sind innerhalb eines Kreises mit etwa 32 dp Radius zentriert, mit
Reserve gegenüber dem sicheren 66-dp-Innenbereich.

Neu rendern mit Python 3, librsvg und ImageMagick:

```sh
python3 androidApp/design/concepts/accordion-negative-space/generate.py
```

Visuell geprüft wurden die Vergleichstafel und die kleinen einfarbigen
Darstellungen. Zusätzlich geprüft wurden Exportabmessungen, transparente
Masken und der sichere Innenbereich. Die echte Launcher-Prüfung folgt nach
Auswahl und Übertragung in Android-Drawables.
