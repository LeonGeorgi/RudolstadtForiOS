# Gemeinsames App-Icon

Das produktive Icon zeigt das ausgewählte Akkordeon aus Ausgangsentwurf 0:
orangefarbener Balg, cremefarbene Gehäuse und violetter Hintergrund `#782C74`.
Android verwendet flache Vektoren; iOS dieselben Konturen in zwei nativen
Icon-Composer-Materialgruppen. Klaviatur, Knopflöcher, Gehäusefugen und
Faltenschlitze sind echte transparente Aussparungen.

## Geometrie

Das Motiv ist nach seinem gefüllten Flächenschwerpunkt bei (54, 54) auf der
108-dp-Ebene zentriert. Die konvexe Hülle hat dieselbe Fläche wie Googles
horizontale Keyline (52 × 36 dp, Radius 4 dp): 1858,265482 dp². Diese explizite
Gestaltungsregel ergibt **55,598051 × 44,417005 dp** Motivgröße. Der maximale
Konturradius von 31,532424 dp bleibt innerhalb des sicheren Radius von 33 dp.
Berechnung und Quellen: `concepts/shared-hybrid/research-centering-size.md`.

iOS übernimmt dieselbe Proportion: ungefähr 790,728 × 631,709 px auf einem
1024-px-Canvas. Das ist eine gemeinsame Gestaltungsentscheidung, keine von Apple
vorgeschriebene Motivgröße.

## Produktive Dateien

- `launcher-icon.svg`: editierbare 108 × 108-Vektorvorlage ohne Außenmaske.
- `export-icon.py`: erzeugt die Android-Vektoren und den Store-Export daraus.
- `../src/main/res/drawable/ic_launcher_foreground.xml`: farbiger Vordergrund.
- `../src/main/res/drawable/ic_launcher_monochrome.xml`: weiße Alpha-Maske für
  Systemfarben; die Aussparungen bleiben erhalten.
- `../src/main/res/drawable/ic_launcher_background.xml`: vollständig gefüllter
  violetter Hintergrund, dessen Farbe in `values/colors.xml` liegt.
- `../src/main/res/mipmap-anydpi-v26/ic_launcher.xml`: adaptives Icon für alle
  unterstützten Android-Versionen (minSdk 26), einschließlich `monochrome` für
  unterstützte Launcher ab Android 13. Das Manifest verwendet es auch als
  `roundIcon`; die endgültige Form bestimmt der Launcher.
- `play-store-icon.png`: 512 × 512 px, sRGB, 32-Bit-RGBA, vollständig deckend,
  ohne vorgefertigte Außenmaske, Rundung oder äußeren Schatten.
- `../../iosApp/Shared/Resources/Rudolstadt.icon`: produktiver nativer Apple-
  Entwurf mit zwei SVG-Ebenen. Der bestehende Xcode-Verweis und Icon-Name
  `Rudolstadt` werden weiterverwendet. Apples Compiler erzeugt auch die
  statischen Icons für ältere iOS-Versionen.
- `app-icons.png` / `Previews/`: Ansichten der produktiven Ressourcen. Die
  Android-Maske und Systemfarbpalette sind simuliert; iOS ist nativ exportiert.

Das gleiche `.icon`-Paket wurde bei der Einbindung auch im benachbarten
`RudolstadtForiOS`-Checkout aktualisiert. Das KMP-Projekt ist davon unabhängig.
Watch-Icons und Benachrichtigungssymbole bleiben separate Ressourcen.

## Export und Prüfung

Vom Projektstamm mit Python 3, librsvg und ImageMagick:

```sh
python3 androidApp/design/export-icon.py
./gradlew :androidApp:processDebugResources --offline
```

Am 29. Oktober 2026 geprüft: Android-Ressourcenkompilierung, native Apple-
Asset-Kompilierung für iPhone/iPad mit Mindestziel iOS 18, die dabei erzeugten
statischen Icons, vollständige SVG-Referenzen in beiden Apple-Projektkopien,
Übereinstimmung der Pfade mit dem normalisierten Entwurf, sichere Motivgrenzen
und Store-PNG-Format. Die produktiven iOS-Ansichten wurden in Standard, Dark,
TintedLight und ClearLight nativ für Designgeneration 26 exportiert.
Eine Prüfung im laufenden Launcher bzw. auf dem Home-Screen steht noch aus.

## Plattformquellen

- [Android Adaptive Icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
- [Google Design: Designing Adaptive Icons](https://medium.com/google-design/designing-adaptive-icons-515af294c783)
- [Google Play Icon Design Specifications](https://developer.android.com/distribute/google-play/resources/icon-design-specifications)
- [Apple App Icon Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
