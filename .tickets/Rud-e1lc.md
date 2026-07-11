---
id: Rud-e1lc
status: closed
deps: [Rud-8z2c]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-5hbr
tags: [approved, tests, testability, userdefaults, date-time, localization, effort-medium, confidence-high]
---
# Zeit, Locale und UserDefaults in Tests deterministisch isolieren

Globale Abhängigkeiten von Date.now, Calendar.current, Locale.current und UserDefaults.standard aus testrelevanter Fach- und Zustandslogik entfernen oder kontrollierbar machen.

## Design

Kleine Initializer-Parameter oder fokussierte Abhängigkeitstypen verwenden. UserPreferencesStore erhält einen isolierbaren UserDefaults-Store; Zeitlogik akzeptiert now, Calendar und bei Bedarf Locale oder TimeZone. Keine allgemeine DI-Infrastruktur einführen.

## Acceptance Criteria

Tests verändern keine Standard-UserDefaults des Testprozesses; Zeit- und Sprachtests setzen ihre Umgebung explizit; Tests sind in beliebiger Reihenfolge und parallel reproduzierbar; bestehendes Produktionsverhalten bleibt unverändert.

## Notes

**2026-07-11T07:51:55Z**

Implementiert: UserPreferencesStore nutzt injizierbare UserDefaults; Tests verwenden eindeutige isolierte Suites und NewsServiceTests laufen nicht mehr serialisiert. Clock/Calendar/Locale sind in DataLoader, NewsService, FestivalProfileStore, FestivalDateUtilities, Event-/Empfehlungslogik, Suche und Länder-Lokalisierung explizit injizierbar; Produktionsdefaults bleiben .standard/.now/.current. 13 deterministische Regressionstests ergänzt (Suite jetzt 56 Tests). Statisch verifiziert: plutil OK, git diff --check OK, keine globalen Zeit-/Locale-Abhängigkeiten oder ungeinjizierten UserSettings in Tests. Laufzeittest noch nicht ausgeführt, da Builds laut AGENTS.md eine ausdrückliche Nutzerfreigabe benötigen.

**2026-07-11T07:57:41Z**

Laufzeitverifikation auf iPhone 17e, iOS 26.5: Cold Run 56/56 Tests in 13 Suites erfolgreich, reine Swift-Testing-Zeit 0,405 s, xcodebuild gesamt 41,22 s. Zweiter Warm Run mit abweichender paralleler Reihenfolge ebenfalls 56/56 erfolgreich, reine Testzeit 0,283 s, gesamt 19,89 s. Produktions-App und Test-Target kompilierten mit normaler Simulator-Signierung. Damit sind Isolation, Parallelisierbarkeit und Reproduzierbarkeit bestätigt.
