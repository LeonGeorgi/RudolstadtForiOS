---
id: Rud-e1lc
status: open
deps: [Rud-8z2c]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-5hbr
tags: [needs-approval, tests, testability, userdefaults, date-time, localization, effort-medium, confidence-high]
---
# Zeit, Locale und UserDefaults in Tests deterministisch isolieren

Globale Abhängigkeiten von Date.now, Calendar.current, Locale.current und UserDefaults.standard aus testrelevanter Fach- und Zustandslogik entfernen oder kontrollierbar machen.

## Design

Kleine Initializer-Parameter oder fokussierte Abhängigkeitstypen verwenden. UserPreferencesStore erhält einen isolierbaren UserDefaults-Store; Zeitlogik akzeptiert now, Calendar und bei Bedarf Locale oder TimeZone. Keine allgemeine DI-Infrastruktur einführen.

## Acceptance Criteria

Tests verändern keine Standard-UserDefaults des Testprozesses; Zeit- und Sprachtests setzen ihre Umgebung explizit; Tests sind in beliebiger Reihenfolge und parallel reproduzierbar; bestehendes Produktionsverhalten bleibt unverändert.
