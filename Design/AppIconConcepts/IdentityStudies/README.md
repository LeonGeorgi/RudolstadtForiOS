# Festival identity icon studies

Three editable SVG concepts derived from the festival identity research in this
conversation. These files are design studies; they do not replace the app icon.

| File | Direction |
| --- | --- |
| `01-festivalvogel.svg` | An original accordion-playing bird with an exaggerated beak, feather crown and dancing legs. Figurative humour and movement translate the poster tradition into a compact silhouette. |
| `02-ru-im-takt.svg` | The two existing letter contours in cream and copperorange. The outline data is taken from `../Refined/08-ru-signet.icon/Assets/Originalschriftzug.svg`, which traces the app's existing lettering. No substitute font is used. |
| `03-leuchtobjekt.svg` | An original faceted paper lantern with a hanging cord, contrasting paper planes and a tassel. It draws on the festival's illuminated objects without reproducing a particular installation. |

## Shared palette

| Role | sRGB |
| --- | --- |
| Deep violet | `#492B55` |
| Warm cream | `#F5E7CE` |
| Copperorange | `#EAA16A` |

This is a proposed palette for these studies, not a documented official palette.

## Editing and previews

Each concept is a standalone 1024 × 1024 SVG with a full square background,
named artwork groups, accessible title and description, and no raster images,
external resources, fonts, scripts, gradients, filters or shadows. The
background can be removed by deleting the `background` group.

`vergleich.svg` and `vergleich.png` compare the concepts at 416, 96, 60 and 40
pixels. Rounded masks exist only in the comparison. These are flat design
previews, not Apple's native icon masks or Icon Composer material renderings.
Dark and tinted appearances and the actual iOS Home Screen remain unverified.

To regenerate the lettering study, comparison and PNG previews using the
existing local `rsvg-convert` installation:

```sh
python3 Design/AppIconConcepts/IdentityStudies/render-studies.py
```

Edit the bird and lantern SVGs directly. Edit `make_lettering()` in the renderer
to change the lettering treatment; the renderer regenerates that SVG.

## Identity references

- [Jürgen B. Wolff's festival artwork archive](https://jbwolff.de/tff-rudolstadt.html)
- [The festival's account of its visual identity](https://www.rudolstadt-festival.de/en/archive/art-work.html)
- [The design team's workshop film](https://www.youtube.com/watch?v=BLGxo_u6_oI)

Verification: all SVGs parsed as XML and rendered successfully with librsvg;
the comparison was visually inspected. No app build, tests or launch performed.
