# Android-Icon-Vorschläge

Sechs Entwürfe zur Auswahl. Die bestehenden Launcher-Ressourcen werden durch
diese Dateien nicht verändert. Alle Hintergründe sind einfarbig.

| Variante | Richtung | Abwägung |
| --- | --- | --- |
| A · Original pur | Weißer Originalschriftzug auf dem iOS-Violett | Stärkste Nähe zum bisherigen Icon; bei kleinen Größen viele Buchstaben. |
| B · Original hell | Violetter Originalschriftzug auf hellem Grund | Ruhigere, hellere Alternative mit derselben Silhouette. |
| C · ru Signet | Die ersten zwei Originalbuchstaben als großes Zeichen | Gute Verbindung zur Wortmarke mit weniger Details. |
| D · ru Zweiklang | Dasselbe Signet in Creme und warmem Orange auf dunklem Violett | Eigenständiger Farbeindruck; in der Systemfarbe identisch zu C. |
| E · R als Band | Neu gezeichnetes großes R mit schrägen Abschlüssen | Kompakt und klar, aber weniger eng an die vorhandene Wortmarke gebunden. |
| F · Festivalplan | Ein gefalteter Plan mit einer Route | Vermittelt Programm und Orientierung; entfernt sich am stärksten von iOS. |

`vergleich.png` zeigt jeden Vorschlag mit einer runden Maske, einer abgerundeten
Maske, einer simulierten Systemfarbe und bei 48 bzw. 64 px. Die Systemfarbe ist
eine illustrative Vorschau. Bei F wird die Route dabei als Aussparung gezeigt;
für eine Übernahme wäre diese als transparente monochrome Maske umzusetzen.

Die einzelnen SVG-Dateien enthalten eine vollständige 108 × 108-Ebene mit
getrennt benanntem Hintergrund und Motiv. Ihre PNG-Dateien zeigen den mittleren
72 × 72-Ausschnitt als quadratische Ansicht in 1024 px. Außenrundungen entstehen
ausschließlich auf der Vergleichstafel.

Die Vektorpfade in A bis D stammen aus der bereits erstellten
`../launcher-icon.svg`. C und D verwenden die r- und u-Konturen dieses Originals,
keine Ersatzschrift. E und F sind neue Vektorentwürfe.

Neu rendern mit Python 3 und librsvg:

```sh
python3 androidApp/design/concepts/generate.py
```

Die Vorschauen wurden visuell geprüft. Es handelt sich um Auswahlentwürfe;
eine Prüfung im Android-Launcher folgt nach Auswahl und Einbindung.
