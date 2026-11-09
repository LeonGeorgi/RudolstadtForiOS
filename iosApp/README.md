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

## Weltkarte mit lokalen Vektoroverlays

Die Künstler-Weltkarte nutzt unter iOS MapKit mit lokalen Vektoroverlays.
Der Karten-/Globus-Button wechselt zwischen einer flachen Karte und Apples Globus.
Norden bleibt oben; Verschieben und Zoomen verwenden die nativen MapKit-Gesten.
Länderauswahl und Künstler-Sheet bleiben erhalten. VoiceOver bietet die Länder
als Aktionen der Weltkarte an.

Die Länderflächen stammen aus den mitgelieferten GeoJSON-Dateien. Ein deckendes
Vektoroverlay zeichnet den Hintergrund und signalisiert mit
`canReplaceMapContent()`, dass es Apples Karteninhalt ersetzt. Es werden keine
Bildkacheln erzeugt oder mitgeliefert. Die Imagery-Konfiguration aktiviert den
Globus ohne Apples Beschriftungen; sie ist kein öffentlicher Offline-Schalter.
MapKit kann weiterhin Netzwerkzugriffe ausführen. Ein erster Start im Flugmodus
auf einem Gerät ohne vorherigen Apple-Kartencache ist noch nicht nachgewiesen.

Im Simulator wurden lokale Länderflächen in 2D und auf dem Globus einschließlich
Projektionswechsel visuell geprüft. Eine kleine unbemalte Kappe am Pol bleibt:
MapKit begrenzt die Overlaydarstellung dort trotz erweitertem Hintergrundbereich.
Der gezielte Test `ArtistMapKitWorldMapTests` enthält Bilder der drei Zustände
Globus → 2D → Globus. Farben, Auswahl, Overlays und der Verzicht auf Bildkacheln
werden ebenfalls geprüft.

macOS und die kleinen Ländervorschauen verwenden ihre bisherige
MapKit-Darstellung.

[Firebase-Profile und Freunde](../docs/firebase-friends.md) · [Watch-Transport](../docs/apple/watch.md) ·
[Festivaldaten](../docs/festival-data.md) · [Screenshot-Automation](../docs/screenshots.md)
