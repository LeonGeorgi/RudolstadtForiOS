# Transparenz von Navigationszielen in Karten-Sheets

Recherche: 21. Oktober 2026. Nachtrag mit Simulatorvergleich und Implementierung: 22. Oktober 2026.

## Ergebnis

**Die Vermutung wurde inzwischen mit der echten Bühnenansicht in einem begrenzten Simulatoraufbau reproduziert und durch die gezielte Hintergrundänderung bestätigt.** Der veröffentlichte Entwicklerbericht beschreibt denselben Effekt. Der Verweis auf `ContainerBackgroundPlacement.navigation` allein belegt hingegen nur die Existenz eines eigenen Navigationshintergrunds, nicht dessen Standarddarstellung ab der zweiten Ebene.

## Was die Quellen tatsächlich belegen

Apple erklärt in [WWDC25: Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/), dass Sheets in Teilhöhe unter iOS 26 standardmäßig Liquid Glass verwenden. Beim Übergang zur vollen Höhe wird der Hintergrund deckend. Apple empfiehlt außerdem, eigene Sheet-Hintergründe auf ihre Notwendigkeit zu prüfen. **Das betrifft die Präsentation und ihre Höhe; die Session beschreibt an dieser Stelle keinen Wechsel des Hintergrunds beim Push eines Navigationsziels.**

Die Apple-Dokumentation zu [`containerBackground(_:for:)`](https://developer.apple.com/documentation/swiftui/view/containerbackground(_:for:)) zeigt, wie einzelne `NavigationLink`-Ziele ihren Navigationshintergrund setzen. Dieser Hintergrund füllt den umgebenden Container und ist deshalb von einem gewöhnlichen View-`background` zu unterscheiden. [`ContainerBackgroundPlacement.navigation`](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/navigation) benennt den Hintergrund innerhalb von `NavigationStack` beziehungsweise `NavigationSplitView`. **Keine dieser beiden Beschreibungen sagt ausdrücklich, dass der Root transparent und jedes gepushte Ziel standardmäßig deckend ist.**

**Direkter Erfahrungsbericht mit Beispielcode:** Natalia Panferova beschreibt am 9. September 2025 in [SwiftUI Liquid Glass sheets with NavigationStack and Form](https://nilcoalescing.com/blog/LiquidGlassSheetsWithNavigationStackAndForm/) genau die fragliche Unterscheidung: Der Root des `NavigationStack` erhält keinen deckenden Inhaltshintergrund; gepushte Ziele besitzen eine zusätzliche deckende Hintergrundebene. Ihr Beispiel setzt `.containerBackground(.clear, for: .navigation)` direkt auf das Ziel. Bei dem verwendeten `Form` wird zusätzlich dessen eigener Hintergrund ausgeblendet. Der Beitrag zeigt Code und Abbildungen für Light und Dark Mode und ist damit eine Primärquelle für ihre eigene Beobachtung, keine Apple-Aussage und kein von uns ausgeführter Test. Der Kontext ist iOS 26; eine konkrete Betriebssystem-Patchversion oder übergreifende Zusage für iOS 18 und 27 wird nicht angegeben.

Apple dokumentiert [`scrollContentBackground(.hidden)`](https://developer.apple.com/documentation/swiftui/view/scrollcontentbackground(_:)) separat für Hintergründe von scrollbaren Inhalten und zeigt ein `List`-Beispiel. Dieser Modifier ersetzt weder das Entfernen ausdrücklich gesetzter eigener Hintergründe noch die Kontrolle des Navigationscontainers.

## Einordnung für diese App

- `ArtistDetailView.swift` setzt zweimal Hintergrundflächen hinter Inhaltsbereiche und einmal `artistTheme.pageBackground.ignoresSafeArea()` hinter die gesamte Ansicht. Das aktuell verwendete Theme stammt aus `ArtistDetailTheme.fallback(for:)` und verwendet `systemBackground`. Diese ausdrücklich gesetzten Flächen sind unabhängig vom Navigationscontainer zu berücksichtigen.
- `StageDetailView.swift` setzt keinen vergleichbaren ganzflächigen Hintergrund. Die Hintergrundfarbe des Bereichs mit nahen Bühnen und die Hervorhebung einzelner Konzertzeilen erklären für sich keine deckende Fläche hinter der gesamten nächsten Navigationsseite. Der veröffentlichte Bericht passte deshalb besonders gut zu diesem Teil des beobachteten Fehlers. Der unten dokumentierte Simulatorvergleich bestätigt inzwischen die Navigationshintergrund-Ursache für die Bühnenansicht.
- Die im installierten Apple-SDK deklarierte Platzierung `.navigation` ist ab iOS 18 verfügbar, also innerhalb unseres Mindestziels. Sie ist dort ausdrücklich für macOS als nicht verfügbar markiert. Eine spätere Implementierung müsste plattformspezifisch bleiben. Die Verfügbarkeit eines Modifiers belegt kein identisches Laufzeitverhalten auf allen unterstützten OS-Versionen.

## Sinnvoller nächster Nachweis

Dieser Nachweis wurde am 22. Oktober 2026 durchgeführt; Details folgen im Nachtrag.

## Simulatorvergleich und Umsetzung am 22. Oktober 2026

Ein temporärer Testaufbau zeigt die echte `StageDetailView` über einer roten Fläche in einem nativen Sheet mit festem Medium-Detent. Dieselbe Bühnenansicht wird danach auf den Navigationsstapel geschoben. Vor der Korrektur wechselt die gemessene leere Hintergrundfläche von RGB `(255, 139, 142)` zu deckendem Weiß `(255, 255, 255)`. Nach `.containerBackground(.clear, for: .navigation)` bleibt der Messwert unverändert. Die gerenderten Bilder wurden ebenfalls geprüft.

Ein weiterer Vergleich mit der echten `ArtistDetailView` besteht nach Entfernen ihrer eigenen Seitenhintergründe im Karten-Sheet ebenfalls. Die Künstlerprüfung nutzt die reguläre horizontale Größenklasse, damit die gemessene Fläche außerhalb des Künstlerbilds liegt. Der bestehende Test für die unveränderte Sheet-Höhe beim Wechsel zwischen Pins besteht weiterhin. Beide Testmethoden, einschließlich der zwei Hintergrund-Testfälle, liefen erfolgreich auf dem iPhone-17-Simulator mit iOS 27.0.

Die Umsetzung verwendet einen auf iOS-Karten-Sheets begrenzten Environment-Wert `isPresentedInMapSheet`. Bühnen- und Künstlerdetails entfernen in diesem Kontext den Navigationshintergrund; Künstlerdetails lassen zusätzlich ihre eigenen Seitenflächen durchsichtig. Der native Präsentationshintergrund bleibt zuständig für Material und den Übergang zwischen Teilhöhe und voller Höhe. Normale Detailseiten behalten ihre bisherigen Hintergründe. Die gemeinsame Hintergrundkomponente wurde zusätzlich gegen macOS 12.2 typgeprüft; `.navigation` wird nur unter iOS verwendet.

Der temporäre Messaufbau wurde anschließend entfernt. Ein vollständiger Klickdurchlauf in den Festival- und Weltkarten-Sheets sowie Prüfungen auf iOS 18 und im Dark Mode sind noch nicht erfolgt. Die App-Integration ist gegenüber dem isolierten Vergleich weiterhin separat zu beurteilen.
