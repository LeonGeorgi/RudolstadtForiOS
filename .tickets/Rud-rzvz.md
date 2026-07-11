---
id: Rud-rzvz
status: open
deps: [Rud-8z2c, Rud-8pt3, Rud-7t3n, Rud-6k9s]
links: []
created: 2026-07-11T07:04:53Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-gqey
tags: [needs-approval, tests, test-plans, ci, coverage, performance, effort-medium, confidence-high]
---
# Full-Testplan und Release-Gate in Scheme und CI verankern

Einen eindeutigen lokalen und automatisierten Ausführungspfad für die vollständige Release-Suite schaffen. Der vorgezogene Fast-Testpfad wird separat in Rud-6k9s umgesetzt.

## Design

Einen Full-Testplan inklusive iOS- und macOS-Smokes definieren. CI-Artefakte und verständliche Fehlerausgabe vorsehen; Coverage als Trend und nicht als pauschales 100-Prozent-Gate verwenden. Performance nur für stabile, relevante Baselines messen.

## Acceptance Criteria

Der Full-Testplan ist über ein geteiltes Scheme ausführbar; CI führt ihn in einem dokumentierten Release- oder manuellen Pfad aus; Testergebnisse und Coverage werden als Artefakte bereitgestellt; ein klarer fehlgeschlagener Test blockiert das Release-Gate; der Fast-Pfad aus Rud-6k9s bleibt unabhängig nutzbar.
