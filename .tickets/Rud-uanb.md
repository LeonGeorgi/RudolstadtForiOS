---
id: Rud-uanb
status: closed
deps: []
links: []
created: 2026-07-11T03:11:27Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-dknv
tags: [approved, design-audit, ios26, news, toolbar, navigation, effort-medium, confidence-medium]
---
# Neue News global sichtbar machen und Toolbar-Dichte reduzieren

Der globale Megafon-Button mit großem Ungelesen-Badge konkurriert in jedem Root-Tab mit Titel und screenspezifischen Aktionen. Zeitplan und Künstler wirken dadurch besonders dicht. Gleichzeitig sind News während des Festivals zu wichtig, um neue Meldungen nur hinter dem Mehr-Tab auffindbar zu machen. Die bestehende Fünf-Tab-Struktur mit Orte, Zeitplan, Künstler, Freunde und Mehr bleibt erhalten.

## Design

- Die globalen Megafon-Buttons aus den Root-Toolbars entfernen.
- News dauerhaft als klar bezeichneten, gut sichtbaren Eintrag im Mehr-Tab anbieten. Dieser Einstieg dient vor allem als Archiv für bereits gelesene Meldungen.
- Sobald mindestens eine News ungelesen ist, mit `tabViewBottomAccessory` eine native iOS-26-Statusfläche direkt an der Tabbar anzeigen. Sie ist aus jedem Root-Tab mit einem Tap erreichbar und öffnet die News-Liste.
- In der erweiterten Darstellung mindestens Ungelesen-Anzahl und News-Bezug eindeutig zeigen; eine kurze aktuelle Überschrift darf ergänzt werden, wenn sie ohne unruhiges Ticker-Verhalten und ohne problematische Textkürzung funktioniert.
- Die Darstellung an `tabViewBottomAccessoryPlacement` anpassen: oberhalb der regulären Tabbar informativ, bei minimierter Tabbar kompakt und weiterhin eindeutig bedienbar.
- Die Accessory nicht allein durch das Öffnen der News-Liste ausblenden. Sie bleibt sichtbar, solange mindestens eine aktuelle Meldung ungelesen ist, und verschwindet erst bei einem Ungelesen-Zähler von null. Ohne ungelesene News darf sie keinen dauerhaften Screen-Platz beanspruchen.
- Bestehende Push-Navigation zu einem konkreten News-Beitrag beibehalten.
- Keine Tabs zusammenlegen, umbenennen oder durch News ersetzen.

## Acceptance Criteria

- Orte, Zeitplan, Künstler, Freunde und Mehr bleiben eigenständige Root-Tabs.
- In den Root-Toolbars wird kein globaler News-Button mehr angezeigt; Titel und screenspezifische Aktionen behalten ausreichend Platz.
- Bei mindestens einer ungelesenen News ist die Bottom-Accessory in jedem Root-Tab sichtbar und die News-Liste mit genau einem Tap erreichbar.
- Die Accessory vermittelt die Ungelesen-Anzahl auch mit VoiceOver eindeutig und besitzt eine ausreichend große Bedienfläche.
- Das bloße Öffnen der News-Liste entfernt den Hinweis nicht, solange ungelesene Meldungen verbleiben.
- Bei null ungelesenen News ist die Accessory vollständig ausgeblendet und reduziert die nutzbare Screen-Höhe nicht.
- Die News-Liste bleibt unabhängig vom Ungelesen-Status dauerhaft als gut sichtbarer Eintrag im Mehr-Tab erreichbar.
- Das Öffnen einer News-Push-Mitteilung führt weiterhin direkt zum zugehörigen Beitrag.
- Reguläre und kompakte Accessory-Darstellung werden auf iPhone 17e und iPhone 17 Pro mit Zeitplan, Künstlerliste und Karte bewertet; dabei werden Dynamic Type, VoiceOver sowie Light und Dark Mode berücksichtigt.

## Notes

**2026-07-11T09:27:38Z**

Umgesetzt: globale News-Toolbar-Buttons entfernt, dauerhafter News-Eintrag im Mehr-Tab ergänzt und native iOS-26-Bottom-Accessory mit erweiterter/kompakter Darstellung, VoiceOver-Zähler und Ein-Tap-Navigation hinzugefügt. Push-Deep-Link blieb unverändert. Verifiziert per XcodeBuildMCP-Build sowie visuell auf iPhone 17 Pro und iPhone 17e mit Maestro/XcodeBuildMCP in regulärer und kompakter Darstellung, Light/Dark Mode und normaler sowie zuvor versehentlich XXL-Dynamic-Type-Darstellung.

**2026-07-11T09:36:31Z**

Follow-up umgesetzt: Tap auf die Bottom-Accessory präsentiert die News-Liste nun als natives großes SwiftUI-Sheet mit matchedTransitionSource/navigationTransition(.zoom), großem Detent, Drag Indicator, Schließen-Button und eigenem NavigationStack. Beitragsnavigation im Sheet per Maestro erfolgreich geprüft; visueller Card-Zustand per XcodeBuildMCP bestätigt. Push-Deep-Link und Mehr-Tab-Route blieben unverändert. Build erfolgreich, git diff --check sauber.

**2026-07-11T09:41:02Z**

Follow-up: gekoppelte Zoom-/matched-Transition wieder entfernt. Das News-Sheet verwendet nun die native SwiftUI-Standardpräsentation von unten; Sheet, Drag Indicator, Schließen und eigener NavigationStack bleiben erhalten. Build & Run erfolgreich, Öffnen und Sheet-Zustand mit Maestro/XcodeBuildMCP geprüft.

**2026-07-11T09:45:20Z**

Follow-up: Pull-to-refresh ist für die im Bottom-Accessory-Sheet geöffnete NewsListView deaktiviert; reguläre News-Routen behalten die Geste und der Toolbar-Refresh bleibt überall verfügbar. Build & Run erfolgreich. Maestro-Test: Sheet geöffnet, Abwärtsgeste direkt auf erstem Listeneintrag ausgeführt, Sheet erfolgreich geschlossen und Accessory wieder sichtbar.

**2026-07-11T09:48:12Z**

Follow-up: Chevron-Schließen-Button aus der News-Sheet-Toolbar sowie zugehörige Lokalisierung entfernt. Übrig bleiben nativer Drag Indicator und Toolbar-Refresh. Build & Run erfolgreich; Button-Abwesenheit im Sheet per Maestro und XcodeBuildMCP bestätigt.

**2026-07-11T09:52:01Z**

Follow-up: Accessory-Typografie an Apple-Music-Mini-Player angenähert (Titel subheadline semibold, Zähler caption, kleineres Icon und Padding). Reguläre und minimierte Platzierung verwenden nun identische Textinhalte; im Inline-Zustand entfällt nur der Chevron. Build & Run erfolgreich, beide Platzierungen auf iPhone 17e mit Maestro/XcodeBuildMCP optisch geprüft.

**2026-07-11T09:57:39Z**

Follow-up: Toolbar-Aktion zum Markieren aller aktuellsprachigen News als gelesen ergänzt. Vor der Sammelaktion erscheint ein Bestätigungsdialog; bei null ungelesenen Meldungen ist die Aktion deaktiviert. UserSettings-Batch-Operation dedupliziert IDs. App-Build und gezielter Unit-Test erfolgreich. Dialog und Bestätigung mit Maestro/XcodeBuildMCP geprüft; nach Bestätigung verschwindet die Bottom-Accessory vollständig.

**2026-07-11T10:06:47Z**

Follow-up: Die Bottom-Accessory bleibt während eines bereits geöffneten News-Sheets als Präsentations-Host erhalten, auch wenn alle Meldungen als gelesen markiert werden. Erst nach dem manuellen Schließen wird der Host freigegeben und die Accessory bei null ungelesenen Meldungen entfernt. Build & Run erfolgreich; kompletter Ablauf auf iPhone 17e mit Maestro geprüft und optisch per Screenshots bestätigt.

**2026-07-11T10:11:54Z**

Follow-up: Die separaten News-Toolbar-Buttons wurden durch ein einzelnes Ellipsis-Menü ersetzt. Das Menü enthält Aktualisieren mit arrow.clockwise sowie Alle als gelesen markieren mit checkmark.circle; der Bestätigungsdialog bleibt nachgeschaltet. Menü ist bei null ungelesenen Meldungen korrekt deaktiviert und bei ungelesenen Meldungen aktiv. Build & Run erfolgreich, Menü und Dialog auf iPhone 17e mit Maestro optisch geprüft.

**2026-07-11T10:15:52Z**

Follow-up: tabBarMinimizeBehavior ist nun an die sichtbare News-Accessory gekoppelt. Mit Accessory bleibt .onScrollDown aktiv; ohne Accessory wird explizit .never verwendet, sodass die Tab-Leiste dauerhaft vollständig sichtbar bleibt. Build & Run erfolgreich. Auf iPhone 17e per Maestro alle Meldungen gelesen, Sheet geschlossen, News-Liste weit gescrollt und die weiterhin vollständige Tab-Leiste optisch bestätigt.

**2026-07-11T10:27:41Z**

Follow-up: Die Accessory zeigt nun den lokalisierten Ungelesen-Zähler in der ersten Zeile und die formatierte Kurzbeschreibung der ungelesenen News in der zweiten. Bei mehreren Meldungen wechseln die Überschriften alle 3 Sekunden mit einer 0,4-s vertikalen Move/Opacity-Transition; Reduce Motion verwendet nur ein kurzes Fade. Reguläre und minimierte Darstellung behalten denselben Text. Deutsche Formulierung auf Mitteilung/Mitteilungen angepasst. Build & Run erfolgreich; zwei ungelesene Meldungen auf iPhone 17e mit Maestro erzeugt, Wechsel als Video geprüft sowie reguläre und minimierte Accessory optisch bestätigt.

**2026-07-11T10:28:37Z**

Follow-up: Wechselintervall der ungelesenen Überschriften von 3 auf 5 Sekunden erhöht; Animation bleibt unverändert.

**2026-07-11T11:51:45Z**

Follow-up: Accessory-Zeile kombiniert nun formatierte Kurz- und Langbeschreibung jeder ungelesenen Meldung mit einem mittleren Punkt (Hauptüberschrift · zweite Überschrift). Leere Langbeschreibungen erzeugen keinen Trenner. Build & Run erfolgreich; reguläre und minimierte Darstellung inklusive einzeiliger Kürzung auf iPhone 17e mit Maestro optisch geprüft.

**2026-07-12T14:02:25Z**

Follow-up: Ungelesen-Zähler aus der Textzeile entfernt und als roter Zahlen-Badge direkt am Megafon platziert. Die rotierenden Inhalte sind nun strukturiert: formatierte Kurzbeschreibung oben (subheadline semibold), formatierte Langbeschreibung unten (caption secondary); beide wechseln gemeinsam alle 5 Sekunden mit der bestehenden Transition. VoiceOver kündigt die Anzahl weiterhin ausgeschrieben an. Build & Run erfolgreich; reguläre und minimierte Darstellung auf iPhone 17e geprüft, minimierter Zustand mit Maestro.

**2026-07-12T14:08:53Z**

Experiment: nativen SwiftUI-.badge(unreadCount)-Modifier mit .badgeProminence(.increased) sowohl direkt am Megafon-Image als auch am Wurzel-Button der tabViewBottomAccessory getestet. Beide Varianten kompilierten unter iOS 26.5, renderten im Simulator aber keinen Badge. Den zuvor gebauten und visuell geprüften roten Overlay-Badge wiederhergestellt.

**2026-07-12T14:23:14Z**

Kontrast-Fix: Light-Mode-Fehler über Bildern im minimierten Artists-Grid reproduziert. Ursache war das vom Liquid-Glass-Host dynamisch auf dunkel gesetzte Inhalts-Farbschema; dadurch wurden auch semantische label-Farben weiß. Das tatsächliche App-Farbschema wird nun außerhalb des Accessory-Hosts erfasst und explizit an UnreadNewsAccessory übergeben. Titel, Untertitel und Chevron verwenden daraus feste Light-/Dark-konforme Farben. Build & Run erfolgreich; exakt derselbe Maestro-Flow im Light Mode zeigt schwarzen/dunkelgrauen Text über den Bildern, Dark-Mode-Regression zeigt weiterhin weißen/grauen Text.

**2026-07-12T14:32:45Z**

Native Kontrastlösung umgesetzt: explizite appColorScheme-Weitergabe und feste Schwarz/Weiß-Farben wieder entfernt. Wenn die News-Accessory sichtbar ist, erhält die TabView nun .scrollEdgeEffectStyle(.hard, for: .bottom); Texte und Chevron verwenden wieder .primary/.secondary/.tertiary. Build & Run erfolgreich. Exakter Artists-Grid-Maestro-Flow auf iPhone 17e: Light Mode blendet die Bilder unter der Accessory ausreichend aus und rendert schwarzen/dunkelgrauen Text; Dark Mode rendert weiterhin weißen/grauen Text. Der Modifier ist ausschließlich im shouldShowNewsAccessory-Zweig aktiv.

**2026-07-12T14:47:08Z**

Rollback auf Nutzerfeedback: .scrollEdgeEffectStyle(.hard, for: .bottom) vollständig entfernt, da es auf realem Gerät eine störende einfarbige Leiste hinter der Accessory erzeugt. Vorherigen transparenten Liquid-Glass-Zustand mit explizit weitergereichtem App-Farbschema und stabilen Light-/Dark-Textfarben wiederhergestellt. Build & Run erfolgreich; Artists-Grid per Maestro geprüft, keine durchgehende Scroll-Edge-Fläche mehr sichtbar.

**2026-07-12T15:16:29Z**

Accessibility-Follow-up: Rotationsintervall auf 6 Sekunden erhöht. Automatischer Wechsel ist deaktiviert, wenn accessibilityReduceMotion oder accessibilityVoiceOverEnabled aktiv ist; die Task-ID enthält Inhalte und Accessibility-Zustand, sodass Änderungen zur Laufzeit die Rotation abbrechen und auf die erste Meldung zurücksetzen. Build & Run erfolgreich, normaler 6-Sekunden-Wechsel visuell bestätigt. Weitere Accessibility-Verifikation auf Nutzerwunsch beendet; Nutzer hat das Verhalten selbst erfolgreich geprüft. Temporär aktiviertes Reduce Motion im Simulator anschließend wieder deaktiviert.

**2026-07-12T15:23:46Z**

Follow-up: News werden beim DataStore-Start nun synchron aus dem vorhandenen frischen oder veralteten Disk-Cache veröffentlicht. Der bestehende verzögerte Netzwerk-Refresh läuft anschließend weiter und ersetzt die angezeigten Daten erst nach Abschluss; bei fehlendem/unlesbarem Cache bleibt der bisherige Lade- und Fallback-Pfad erhalten. Regressionstests für frischen/veralteten Cache sowie den unmittelbaren DataStore-Startzustand ergänzt. git diff --check erfolgreich; Simulator-/Unit-Testlauf gemäß vorherigem Nutzerwunsch übersprungen.

**2026-07-14T05:15:36Z**

Follow-up: Die dunkle Künstler-Weltkarte überschreibt nicht das globale App-Farbschema, weshalb die zuvor stabilisierte Accessory-Farbe im Light Mode dunkel blieb. RootTabView verfolgt nun ausschließlich die tatsächlich sichtbare artistWorldMap-Route und verwendet dort für die News-Accessory helle Dark-Backdrop-Farben; bei Weiter-/Zurücknavigation und Tabwechsel gilt wieder das App-Farbschema. Swift-Parse und scoped git diff --check erfolgreich; kein Simulator-Build gestartet.

**2026-07-14T05:24:59Z**

Visuelle Nachverifikation auf ausdrücklichen Nutzerwunsch: aktuellen Stand mit XcodeBuildMCP auf verbundenem iPhone 17e (iOS 26.5) gebaut und gestartet. Mit Maestro MCP semantisch zur Künstler-Weltkarte navigiert und Screenshots aufgenommen. Dark Mode korrekt. Entscheidend: App explizit im Light Theme neu gestartet, dunkle Hybrid-Weltkarte geöffnet; Accessory rendert Titel weiß und Untertitel hellgrau. Nach Maestro-Rücknavigation in die helle Künstler-Gridansicht rendert sie wieder schwarz/dunkelgrau. Build erfolgreich; bidirektionaler Farbschemawechsel visuell bestätigt.
