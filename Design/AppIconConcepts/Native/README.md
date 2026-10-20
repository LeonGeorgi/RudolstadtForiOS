# Native app icon concepts

Six editable Icon Composer packages replace the raster treatment of the initial concepts. They are design candidates, not installed production icons.

| Package | Direction |
| --- | --- |
| `01-r-im-tanzkreis.icon` | Cream lowercase r and copper festival squares |
| `02-akkordeon-herz.icon` | Accordion with heart-shaped bellows |
| `03-mein-programm.icon` | Folded festival programme and personal bookmark |
| `04-programm-kompakt.icon` | Simplified programme with larger lettering |
| `05-festivalband.icon` | Personal festival wristband |
| `06-r-in-kupfer.icon` | Copper r on a light background |

All artwork is solid-color SVG without textures, raster images, pre-rendered highlights, gradients, filters, or shadows. Text is converted to paths from DIN Condensed Bold. Every programme and wristband spells the name as `rudol` / `stadt`, including the previously missing l. Bookmarks do not cover the lettering.

Each package separates its artwork into native groups and layers. Liquid Glass is enabled through `glass: true`; Icon Composer owns the background gradient, translucency, specular highlights, and shadows. The compiled asset catalogs retain vector artwork and native icon stacks with specular effects enabled. The canvas mask comes from Apple's renderer.

The original official reference files and their source URLs are recorded in `../concepts.json`. The earlier PNG concepts remain historical references; use these native packages for further work.

## Previews and checks

`Previews/alle-sechs-native-icons.png` compares all six at large and small sizes. `Previews/alle-sechs-dunkler-hintergrund.png` shows the **same standard appearance** on a dark background; it is not a Dark Mode rendition.

The individual 1024-pixel previews are rendered from Apple's compiled macOS asset catalogs with AppKit. They show Apple's static standard appearance, not a screenshot of the iOS Home Screen or a simulation of dynamic device lighting. Final iOS appearance should be checked on a device or simulator after choosing a candidate.

Each package was compiled independently for macOS 12.2 and iOS 18. No application build or launch is needed for these asset checks. The production project and its selected icon are unchanged by this design workflow.

## Reproduce

From the repository root, regenerate vector sources and Icon Composer packages:

```sh
swift -module-cache-path /private/tmp/rudolstadt-icon-swift-cache \
  Design/AppIconConcepts/generate-native-icons.swift \
  "$PWD/Design/AppIconConcepts/Native"
```

For each package, run `xcrun actool` with its filename stem as `--app-icon`, a dedicated `--compile` output directory, and the appropriate platform and minimum deployment target. Do not add these candidates to the production target until one is selected.

Once the macOS exports are in `/private/tmp/rudolstadt-native-icon-check/<filename-stem>/Assets.car`, reproduce the comparison:

```sh
swift -module-cache-path /private/tmp/rudolstadt-icon-swift-cache \
  Design/AppIconConcepts/render-native-previews.swift \
  /private/tmp/rudolstadt-native-icon-check \
  "$PWD/Design/AppIconConcepts/Native/Previews"
```

This follows Apple's [Icon Composer artwork guidance](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer): export flat vector layers and let Icon Composer supply materials and effects.
