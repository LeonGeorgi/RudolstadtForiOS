# Festival objects with original lettering

This round combines the earlier creative directions with the festival's actual letterforms. It does not substitute a font or return to a standalone wordmark.

- `10-festivalpass.icon`: a notched ticket/pass with a copper tear-off section and the original stacked lettering.
- `11-festivalplan.icon`: an asymmetric folded programme/map, original stacked lettering, and a small printed route on the flap.
- `12-festivalband.icon`: a wristband loop with the festival's original horizontal lettering.

The object surfaces use native Icon Composer glass, combined lighting, translucency, and shadows. Lettering and the map route are flat printed vector ink on those surfaces, avoiding individual bevels around every glyph or route point. All source artwork is SVG, without textures, raster images, filters, or pre-rendered lighting.

The stacked lettering comes from `../Refined/07-original-pur.icon/Assets/Originalschriftzug.svg`. The horizontal lettering in `SourceAssets/festival-wordmark-horizontal.svg` is traced locally with Apple's Vision framework from the official logo in `../References/festival-logo.png`; all ten letters and their counters are retained. Its source URL is recorded in `../concepts.json`.

Run `../generate-creative-icons.py` to regenerate the packages. To retrace the horizontal source, run `../trace-horizontal-wordmark.swift` with the official reference PNG and output SVG paths; contour detection requires access to Apple's local image-processing services.

`Previews/festivalmotive-vergleich.png` shows the actual compiled macOS icon assets at large and small sizes. `Previews/festivalmotive-dunkler-hintergrund.png` shows the same standard appearance on a dark background. These are not screenshots of the iPhone Home Screen.

macOS 12.2 and iOS 18 asset compilation were verified. The app was not built or launched, and its selected icon remains unchanged. After compiling each package into its own output directory, run `../render-native-previews.swift` with the compiled root, preview directory, and `--creative` to reproduce the comparisons.
