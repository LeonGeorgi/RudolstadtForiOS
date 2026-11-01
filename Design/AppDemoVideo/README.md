# Rudolstadt – App-Demovideo

Zwei Fassungen mit eigener Bildführung, jeweils 27,7 Sekunden und 60 fps:

- Hochformat: `output/rudolstadt-news-hochformat.mp4`, 1080 × 1920.
- Querformat: `output/rudolstadt-news-querformat.mp4`, 1920 × 1080.

Die vorherigen Exporte bleiben zum Vergleich erhalten. Der Quellstand der
vorherigen Fassung liegt lokal in `captures/version-3/`.

## Handlung und Rhythmus

Ein Konzert verbindet die Handlung: Freunde empfehlen RIAN, du bewertest den
Künstler mit drei Herzen und merkst sein Konzert. Im Samstagplan filterst du
persönlich, findest RIAN um 19 Uhr wieder und gehst über die Konzertbühne
Heinepark zur interaktiven Karte. Über den News-Hinweis öffnest du danach den Feed und
den Artikel „Festival Plus“.

| Zeit | Handlung und Bildführung |
| --- | --- |
| 0–2,8 s | Freunde empfehlen; die tatsächlichen Künstlerbilder fliegen ein |
| 2,8–4,6 s | RIAN öffnen, Kamera fährt zum Künstlerprofil |
| 4,6–6,5 s | Natives Bewertungs-Popover und Herzanimation in Nahaufnahme |
| 6,5–8,3 s | Konzert speichern, Kamera folgt dem Knopf, Wechsel zum Plan |
| 8,3–12,5 s | Samstag, einfliegende Konzertkästchen und persönlicher Filter |
| 12,5–15,4 s | Listenwechsel, RIAN wiederfinden und Bühne öffnen |
| 15,4–19,85 s | Bühnenvorschau und nativer Übergang zur interaktiven Karte |
| 19,85–24,7 s | News-Sheet öffnen, Feed überblicken und „Festival Plus“ lesen |
| 24,7–27,7 s | Kamera zieht zurück; echtes App-Icon und Abschluss |

Die Schnitte der ersten elf Abschnitte folgen dem 130-BPM-Raster. Native
Animationen behalten ihre Originalgeschwindigkeit; Halte- und Ladepausen sind
gekürzt. Die Kamera bewegt sich passend zur Handlung. Beide Seitenverhältnisse
haben eigene Kamerapfade und Textpositionen.

## Bearbeiten und rendern

```sh
npm ci
npm run studio
npm run check
npm run render:portrait
npm run render:landscape
python3 scripts/verify-exports.py
```

Die Konfiguration nutzt die vorhandene Chromium Headless Shell 149 aus dem
Playwright-Cache, PNG-Frames, getrenntes Encoding und ANGLE mit vier parallelen
Frames. Desktop-Chrome 156 erzeugte sporadische Kachelartefakte. Auf einem
anderen Rechner den Browserpfad in `remotion.config.ts` auf eine kompatible
Headless Shell anpassen. Alle für den Render nötigen Medien liegen in `public/`.

`src/camera.ts` enthält die Kamera, `src/Demo.tsx` die Texte und das Originalicon,
`src/Entrances.tsx` die ergänzenden Einflüge. `scripts/cuts.json` dokumentiert die
Schnittbereiche. `scripts/prepare-clips.py` normalisiert variable Simulatorraten
vor dem Schnitt auf 60 fps und erzeugt `public/clips/story.mp4`.

## Originalaufnahmen und Icon

Aufnahmen stammen aus dem vorhandenen, regulär signierten iPhone-17-Simulator.
Der bestehende Screenshot-Modus verwendet das gebündelte Programm 2026 und
Beispielprofile. Produktionscode wurde nicht verändert. Rohaufnahmen,
Maestro-Flows und Diagnostik bleiben lokal im ignorierten `captures/`.

Navigation, Popover, Herzen, Speichern, Tab- und Tageswechsel, Filter,
Listenwechsel, MapKit, News-Sheet und Artikelnavigation sind echte App-Aufnahmen. Remotion ergänzt
Kameraführung, Schrift und Einflüge ausgeschnittener echter Oberflächenelemente.
Äußerer iPhone-Rahmen und Display nutzen aus SwiftUI exportierte kontinuierliche
Konturen (`scripts/phone-contours.swift`).

`public/app-icon.png` ist der unveränderte Export des aktiven
`Shared/Resources/Rudolstadt.icon` durch Apples Icon Composer. Kein nachgebauter
Hintergrund, keine zusätzliche Maske. Reproduzieren vom Repository-Stamm:

```sh
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" \
  "$PWD/Shared/Resources/Rudolstadt.icon" --export-image \
  --output-file "$PWD/Design/AppDemoVideo/public/app-icon.png" \
  --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
```

## Musik

**Funked Up — Joth**, vom Urheber unter **CC0** veröffentlicht:
<https://opengameart.org/content/funked-up>.
Originaldownload: <https://opengameart.org/sites/default/files/Funked%20Up.mp3>.
Lizenz: <https://creativecommons.org/publicdomain/zero/1.0/>.

Der Funk-Track mit Gitarre, Bass und Schlagzeug ersetzt die frühere ruhige
Eigenkomposition vollständig. Er ist von 116 auf 130 BPM beschleunigt, auf
27,7 Sekunden geschnitten und endet nach vierzehn Takten mit einem kurzen
Echoausklang. Die Mischung zielt auf −14 LUFS und maximal −1,5 dBTP.

`scripts/create-soundtrack.py` erzeugt die fertige WAV mit ffmpeg aus
`captures/music-candidates/funked-up.mp3`. Die WAV liegt für offline Render
bereits in `public/`. Keine kommerziellen Künstler-Vorschauen sind eingemischt.
