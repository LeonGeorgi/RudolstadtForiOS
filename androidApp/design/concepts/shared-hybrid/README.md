# Gemeinsamer Akkordeon-Entwurf für Android und iOS

Stand 29. Oktober 2026: Die normalisierte Variante aus `GridNormalized/` ist
in Android und beiden Apple-Projektkopien produktiv eingebunden. Die folgenden
Konzepttafeln bleiben als Entwurfsverlauf erhalten. Aktuelle Ressourcen und
Exportanleitung stehen in `../../README.md`.

Der Entwurf kombiniert den zusammenhängenden Balg von K1 mit der eingeschnittenen
Klaviatur von K3. Gehäusefugen, Knopflöcher, Klaviatureinschnitte und geschlossene
Faltenschlitze sind in beiden Plattformvarianten dieselben Vektorkonturen.

Seit der Auswahl von Ausgangsentwurf 0 wird das Motiv nach seinem tatsächlichen
Flächenschwerpunkt zentriert. Die bisherige Vergleichsbasis bleibt bei 52 dp
Motivbreite auf der gemeinsamen 108-dp-Vorlage. Die neue rasterbasierte Empfehlung
liegt in `GridNormalized/`: 55,598 × 44,417 dp, mit derselben Hüllfläche wie die
horizontale Google-Design-Keyline. Das ist eine reproduzierbare Gestaltungsregel,
kein nachgewiesenes Wahrnehmungsoptimum.
Die frühere Version 0 bleibt in `../accordion-tree/0/` als Vergleich erhalten.
Methodik, Quellen, Messwerte und Grenzen stehen in `research-centering-size.md`.

Die Anschlussfugen laufen vollständig durch die Gehäuseenden. Dadurch bleiben
an ihren Enden keine kleinen Haken oder Spitzen stehen. Die Aussparungen sind
echte boolesche Pfadsubtraktionen. Die exportierten SVG-Ebenen benötigen keine
SVG-Masken, Filter oder vorgerenderten Schatten.

## Dateien

- `foreground.svg`: gemeinsame farbige Vordergrundkonturen auf einer transparenten
  108 × 108-Ebene für Android.
- `monochrome.svg`: dieselben Konturen als weiße transparente Maske.
- `android.svg` / `android.png`: quadratische Farbansicht des mittleren
  72 × 72-Ausschnitts, ohne vorgefertigte Außenmaske.
- `Rudolstadt-Akkordeon.icon`: editierbarer nativer Icon-Composer-Entwurf.
- `Previews/`: die nativen Apple-Exporte und simulierten Android-Launcher-Ansichten.
- `vergleich.svg` / `vergleich.png`: plattformübergreifende Vergleichstafel.
- `measurements.json`: berechnete Schwerpunkt-, Größen- und Sicherheitskennwerte.
- `zentrierung.png`: Vorher-/Nachher-Nachweis mit Mittelpunkt und Flächenschwerpunkt.
- `groessenvergleich.png`: native Größenansichten bei 95 %, 100 % und 105 %.
- `SizeStudies/`: die beiden zusätzlich erzeugten Größenalternativen.
- `GridNormalized/`: neue flächennormalisierte Empfehlung einschließlich nativem
  iOS-Export und editierbarer `.icon`-Datei.
- `grid-analysis.json`: Referenzfläche, Hüllfläche und berechneter Skalierungsfaktor.
- `grid-normalisierung.png`: Referenzform und Größenvergleich für beide Plattformen.
- `grid-proof.py`: reproduzierbare Vergleichstafel aus den vorhandenen Exporten.

## Aufbau auf iOS

Die `.icon`-Datei besitzt einen von Icon Composer erzeugten violetten Hintergrund
und zwei Vordergrundgruppen:

1. Zusammenhängender orangefarbener Balg mit eingeschnittenen Faltenschlitzen.
2. Beide hellen Gehäuse gemeinsam, einschließlich der ausgesparten Klaviatur
   und Knopflöcher.

Beide Gruppen verwenden gemeinsame Beleuchtung (`combined`), natives Glas und
zurückhaltende Transluzenz-/Schattenwerte. Die Materialeffekte entstehen durch
Apples Renderer. Einzelne Tasten oder Knöpfe bekommen keine eigenen Tiefenebenen.

Die Geometrie wird für den Apple-Canvas von 108 auf 1024 Einheiten umgerechnet,
wobei der zentrale Android-Viewport von 72 Einheiten dieselbe Motivgröße erhält.
Die Hintergrunddarstellung und die Außenmaske übernimmt das jeweilige System.

## Vorschauen und Prüfung

Die iOS-Ansichten sind native statische Exporte von Icon Composer 27.1,
explizit mit `--platform iOS --design-generation 26`. Exportiert und visuell
geprüft wurden Default, Dark, TintedLight, TintedDark und ClearLight.
Die Vergleichstafel zeigt vier dieser Apple-Ansichten neben den beiden
Android-Ansichten und jeweils bei 64 px.

Die Android-Außenmaske und die beispielhafte Systemfarbpalette sind simuliert.
Auch Apples native Exporte sind keine Screenshots eines laufenden Home-Screens;
die klare Darstellung verwendet den statischen Hintergrund des Exporters.
Die Prüfung auf dem laufenden Gerät und unter bewegter Beleuchtung bleibt offen.

Geprüft wurden die Abmessungen aller PNGs, die nativen Exporte, die sichere
Android-Zone und die Beschränkung auf zwei SVG-Vordergrundebenen im `.icon`-Paket.
Die frühere Konzeptprüfung hat die produktiven Icons nicht ersetzt; die spätere
Einbindung verwendet die normalisierte Variante wie oben beschrieben.

## Reproduzieren

Vom Projektstamm aus, mit Swift, librsvg und Apples Icon Composer:

```sh
swift -module-cache-path /tmp/rudolstadt-swift-cache \
  androidApp/design/concepts/shared-hybrid/generate.swift \
  "$PWD/androidApp/design/concepts/shared-hybrid"
rsvg-convert androidApp/design/concepts/shared-hybrid/android.svg \
  -o androidApp/design/concepts/shared-hybrid/android.png
python3 androidApp/design/concepts/shared-hybrid/render.py
```

Ein optionaler zweiter Parameter für `generate.swift` variiert die Motivbreite
relativ zu 52 dp (z. B. `0.95` oder `1.05`). Die Skalierung erfolgt immer um den
berechneten Flächenschwerpunkt. `compare-centering.py` erstellt nach Vorliegen
der nativen Größenexporte die beiden Nachweistafeln.

Mit `render.py --sheet-only` lassen sich die bereits vorhandenen nativen
Apple-Exporte wiederverwenden. Die `.icon`-Datei kann direkt in Icon Composer
geöffnet und weiter angepasst werden.
