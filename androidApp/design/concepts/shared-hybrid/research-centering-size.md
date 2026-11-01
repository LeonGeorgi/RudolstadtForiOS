# Schwerpunkt und wahrgenommene Größe

Recherche und Umsetzung vom 29. Oktober 2026. Grundlage ist der ausgewählte
Ausgangsentwurf 0. Die Form und die zwei Materialgruppen bleiben erhalten.

## Was die Forschung tatsächlich hergibt

### Zentrum

[Proffitt, Thomas und O'Brien (1983), *The roles of contour and luminance
distribution in determining perceived centers within shapes*](https://link.springer.com/content/pdf/10.3758/BF03205866.pdf)
trennten die Einflüsse von Kontur und Helligkeitsverteilung experimentell.
In ihren Aufgaben war die Kontur der stärkere Einfluss auf das wahrgenommene
Zentrum; die Helligkeitsverteilung beeinflusste es wesentlich weniger.

[Davi et al. (1993), *The relative roles of vertices and sides in determining
perceptual centres within shapes*](https://pubmed.ncbi.nlm.nih.gov/8213264/)
berichten bei fünf Polygonen ein wahrgenommenes Zentrum näher am
Flächenschwerpunkt als an den anderen verglichenen mathematischen Zentren.

**Ableitung für dieses Icon:** Der geometrische Flächenschwerpunkt des gesamten
Motivs ist eine begründete, reproduzierbare Referenz. Die Anwendung auf unser
mehrteiliges, ausgeschnittenes und materialisiertes Akkordeon ist eine
Gestaltungsableitung, kein direkt an diesem Icon validiertes Wahrnehmungsmodell.
Ein universell garantiertes optisches Zentrum lässt sich daraus nicht behaupten.

Hintergrund, Schatten und Glanz werden nicht als Motivmasse gezählt. So bleibt
die gemeinsame Ausrichtung unabhängig von Plattform, Tönung und Beleuchtung.
Alle Aussparungen werden dagegen vollständig von der Motivfläche abgezogen.

### Wahrgenommene Größe

[Kim, Noguchi und Hibino (2001), *Effects of shape and visual angle on area
perception of geometrical figures*](https://www.jstage.jst.go.jp/article/jjske2001/1/1/1_1_1/_article/-char/en)
zeigen bei flächengleichen Formen unterschiedliche Größeneindrücke und einen
Einfluss des Sehwinkels. Fläche allein reicht daher als Größenmaß nicht aus.

[Pisu et al. (2025), *Biases in the perceived area of different shapes:
A comprehensive account and model*](https://eprints.soton.ac.uk/499185/)
untersuchen solche Verzerrungen in vier Experimenten mit jeweils 35 Erwachsenen
und paarweisen Entscheidungen darüber, welche Form größer wirkt. Ihr Modell
erklärt die untersuchten 22 Form-/Orientierungskombinationen, ist aber kein
allgemein validierter Maßstab für komplexe App-Icons mit Aussparungen und Glas.

**Für einen tatsächlichen Wahrnehmungswert ist ein direkter Größenabgleich
mit Betrachtern am belastbarsten:** dieselben gerenderten System-Icons in
repräsentativer Größe und im gleichen Kontext nebeneinander zeigen, Seiten
randomisieren und die Motivskalierung variieren. Aus den Antworten „welches
Motiv wirkt größer?“ lässt sich eine psychometrische Kurve und ein Punkt
subjektiver Gleichheit (PSE) bestimmen. Das misst die Gleichheit zu einer
gewählten Referenz, nicht automatisch die ästhetisch beste Größe.

Ein solcher Beobachterversuch wurde hier **nicht durchgeführt**. Die berechnete
Fläche, der flächengleiche Kreisdurchmesser, die Außenmaße und der Maximalradius
sind objektive Kennwerte und Kontrollgrößen, keine bereits gemessene Wahrnehmung.

## Plattformregeln und daraus abgeleitete Größenwahl

### Android

Die aktuelle [Android-Dokumentation zu Adaptive Icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
verlangt 108-dp-Ebenen und einen sicheren zentralen Bereich von 66 dp. Sie nennt
48 bis 66 dp für die Motivgröße. Ein Sicherheitsbereich ist keine Aufforderung,
die Fläche vollständig auszufüllen.

Der weiterhin dort verlinkte Beitrag von
[Google Design, *Designing Adaptive Icons*](https://medium.com/google-design/designing-adaptive-icons-515af294c783)
enthält Form-Keylines: Kreis 52 bzw. 36 dp, Quadrat 44 × 44 dp und Rechtecke
52 × 36 bzw. 36 × 52 dp. Das sind Proportionshilfen, keine zwingenden Außenmaße
für jedes beliebige Markenmotiv. Insbesondere kann die pauschale Formulierung
„48 × 48“ nicht sinnvoll bedeuten, jedes breite Motiv in beiden Dimensionen
aufzufüllen oder zu verzerren; die dokumentierten Rechteck-Keylines sind selbst
schmaler. Vorrang hat hier die vollständige sichere Silhouette.

Für das breite Akkordeon wird die **längere Ausdehnung auf 52 dp** gesetzt.
Seine Proportionen bleiben erhalten. Daraus ergeben sich etwa 52 × 41,54 dp.
Die historische horizontale Rechteck-Keyline begründet hier die Ausgangsbreite,
nicht die Behauptung eines exakt vorgeschriebenen Akkordeonformats.

### iOS

Apples [App-Icon-HIG](https://developer.apple.com/design/human-interface-guidelines/app-icons?country=63)
und [Icon-Composer-Anleitung](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
fordern optische Ausgewogenheit, zentrierte wichtige Inhalte, klare Kanten und
Prüfung der Erscheinungsvarianten. Sie geben für dieses Motiv keine feste
Füllquote wie „genau 72,2 %“ vor.

Als gemeinsame Ausgangsgröße wird dieselbe Vektorkontur in den Apple-Canvas
übertragen: 52/72 × 1024 = etwa **739,56 px Motivbreite**. Das sind 72,22 % des
1024-px-Canvas. Diese Prozentzahl ist unsere Umrechnung, keine Apple-Vorschrift.
Die native Glasdarstellung muss im Vergleich beurteilt werden; identische
Konturen garantieren nicht identische wahrgenommene Größe.

## Berechnung und Ergebnis

`generate.swift` berechnet die signierte Fläche und erste Flächenmomente mittels
Green'schem Satz direkt aus den boolesch ausgeschnittenen Bézierpfaden.
Fünfpunkt-Gauß-Quadratur integriert die auftretenden Polynome bis Grad 8 exakt,
abgesehen von Gleitkomma- und Export-Rundung. Löcher tragen mit negativem
Vorzeichen bei. Es wird nicht über die Mitte des umgebenden Rechtecks zentriert.

| Kennwert | Vorher | Zentrierter Standard |
| --- | ---: | ---: |
| Schwerpunkt x | 55,111761 dp | 54,000000 dp |
| Schwerpunkt y | 52,138503 dp | 54,000000 dp |
| Motivbreite | 53,074470 dp | 52,000000 dp |
| Motivhöhe | 42,400930 dp | 41,542541 dp |
| Gefüllte Motivfläche | 1190,613865 dp² | 1142,894884 dp² |
| Flächengleicher Kreisdurchmesser | — | 38,146808 dp |
| Größter Konturabstand zur Iconmitte | — | 29,491790 dp |

Die Schwerpunktkorrektur ist **1,111761 dp nach links und 1,861497 dp nach unten**.
Die zusätzliche Größenkorrektur beträgt linear **−2,02446 %** gegenüber der
vorherigen Version. Der Standard verwendet damit 28,07 % der sichtbaren runden
72-dp-Maskenfläche als gefüllte Motivfläche. Das ist eine Beschreibung dieses
Entwurfs, kein Zielwert für andere Icons.

Der maximale Radius 29,49 dp liegt unter dem sicheren Radius von 33 dp. Auch die
Vergleichsgrößen 49,4 dp und 54,6 dp Breite bleiben mit 28,02 bzw. 30,97 dp
innerhalb dieses Bereichs. Alle drei Varianten sind schwerpunktzentriert.

**Bisherige Ausgangswahl (durch die folgende Rasterregel ergänzt):** 52 dp / rund
740 px Motivbreite. Die Tafeln
zeigen zusätzlich −5 % und +5 % für den optischen Vergleich. Eine endgültige
Aussage zur wahrgenommenen Größenangleichung erfordert den beschriebenen
Beobachterabgleich im Plattformkontext.

## Ergänzung: reproduzierbare Größenregel anhand der Keyline-Fläche

Die neue Empfehlung gleicht die **konvexe Hüllfläche** des Akkordeons an die
Fläche der horizontalen Google-Design-Keyline an: 52 × 36 dp, Eckenradius 4 dp.
Die konvexe Hülle ist der Umriss eines gedachten straff um das Motiv gespannten
Gummibands. Innere Löcher werden dadurch nicht als fehlende Größe gewertet.

Das Vorgehen ist von Androids
[AOSP IconNormalizer](https://android.googlesource.com/platform/prebuilts/fullsdk/sources/android-30/+/refs/heads/androidx-lifecycle-release/com/android/launcher3/icons/IconNormalizer.java)
inspiriert: Der Code bestimmt eine konvexe Hülle und leitet einen linearen
Skalierungsfaktor aus einem Flächenverhältnis über die Quadratwurzel ab.
Der Launcher normalisiert ganze Icons; bei adaptiven Icons berücksichtigt er
die Außenmaske. Unsere Anwendung auf das Vordergrundmotiv und die Wahl dieser
konkreten Referenzfläche sind eine eigene, explizite Gestaltungsregel. Sie sind
keine vom Launcher automatisch vorgenommene Vordergrundkorrektur.

Berechnung:

```text
Referenzfläche = 52 × 36 − (4 − π) × 4² = 1858,265482 dp²
Hüllfläche bei 52 dp Breite = 1625,531238 dp²
Skalierung = √(1858,265482 / 1625,531238) = 1,069193279
Neue Motivgröße = 55,598051 × 44,417005 dp
Maximaler Konturradius = 31,532424 dp < 33 dp sicherer Radius
```

Die Hülle wird mit einem Monotone-Chain-Algorithmus über adaptiv unterteilten
Bézierkonturen (Unterteilungstoleranz 0,0001 dp) berechnet. Der Flächenschwerpunkt
bleibt bei (54, 54) dp. Das Motiv wird gleichmäßig skaliert. Die Referenzform ist
eine Größenhilfe, kein zusätzliches Beschnittrechteck; das Motiv muss nicht
zugleich innerhalb ihrer 52 × 36 dp liegen.

Für iOS wird dieselbe Kontur auf den 1024-px-Canvas übertragen. Daraus ergeben
sich ungefähr 790,728 × 631,708 px bzw. 77,22 % Canvasbreite. Apple empfiehlt
[Grids und zentrierte wichtige Inhalte](https://developer.apple.com/design/human-interface-guidelines/app-icons)
und erläutert das Raster in
[WWDC25: Say hello to the new look of app icons](https://developer.apple.com/videos/play/wwdc2025/220/).
Diese konkrete Motivgröße wird von Apple nicht vorgeschrieben. Sie ist unsere
plattformübergreifende Proportionsentscheidung. Der neue iOS-Standardexport
wurde mit Apples nativem Renderer erstellt und zusammen mit Android visuell
geprüft; die Effekte können die wahrgenommene Größe weiterhin beeinflussen.

Die neue Empfehlung liegt separat in `GridNormalized/`. `grid-normalisierung.png`
zeigt die Flächenregel und den Vergleich; `grid-analysis.json` enthält die Werte.
Die bisherige 52-dp-Version bleibt als Vergleich erhalten. Die produktiven
App-Icons wurden nicht ersetzt.

## Prüfung

Der analytische Schwerpunkt wurde unabhängig anhand hochauflösender, mit Alpha
gewichteter Rastermasken geprüft. Zusätzlich geprüft wurden die sicheren
Motivgrenzen, die Größenalternativen und native iOS-Exporte in Standard-, Dunkel-,
Klar- und Tönungsdarstellung. Eine psychophysische Nutzerstudie und ein Vergleich
auf laufenden Geräten wurden nicht durchgeführt. Die produktiven App-Icons
wurden durch diese Entwurfsarbeit nicht ersetzt.
