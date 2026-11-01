# Native Apple-App

Dieser Ordner enthält das Xcode-Projekt und den nativen SwiftUI-Code von
RudolstadtKMP, einschließlich iOS, macOS, Watch-App, Widget und Apple-Tests.
Wiederverwendbare Fachlogik und Festivaldaten liegen im [KMP-Modul](../shared).

Vom Projektstamm öffnen:

```sh
open iosApp/RudolstadtForiOS.xcodeproj
```

Die iOS-/macOS-Targets sowie Watch-App und Watch-Widget bauen den Kotlin-Kern automatisch über
[`scripts/ios/build-apple-framework.sh`](../scripts/ios/build-apple-framework.sh).
Voraussetzungen und gezielte Testbefehle stehen im [Projekt-README](../README.md).
Der ursprüngliche iOS-Checkout wird nicht benötigt.

- `Shared/`: native App-Komposition, SwiftUI, Apple-Dienste und Kotlin-Anbindung.
  Der Name bezeichnet die gemeinsame Nutzung durch Apple-Targets.
- `iOS/`, `macOS/`, `Watch/`, `Watch Widget/`: Plattform- und Target-Konfiguration.
- `Unit Tests/`, `Tests iOS/`, `Tests macOS/`, `Test Plans/`: Apple-Tests.
- `RudolstadtForiOS.xcodeproj/`: Targets, Schemes, Ressourcen und Build-Phasen.

[CloudKit](../docs/apple/cloudkit.md) · [Watch-Transport](../docs/apple/watch.md) ·
[Festivaldaten](../docs/festival-data.md) · [Screenshot-Automation](../.maestro/app-store-screenshots/README.md)
