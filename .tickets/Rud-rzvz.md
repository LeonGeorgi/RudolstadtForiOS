---
id: Rud-rzvz
status: open
deps: [Rud-8z2c, Rud-8pt3, Rud-7t3n]
links: []
created: 2026-07-11T07:04:53Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-gqey
tags: [needs-approval, tests, test-plans, ci, coverage, performance, effort-medium, confidence-high]
---
# Fast- und Full-Testpläne in Schemes und CI verankern

Eindeutige lokale und automatisierte Ausführungspfade für schnelle Entwickler-Tests und die vollständige Release-Suite schaffen.

## Design

Einen Fast-Testplan für Unit-, Contract- und lokale Service-Tests sowie einen Full-Testplan inklusive UI-Smokes definieren. CI-Artefakte und verständliche Fehlerausgabe vorsehen; Coverage als Trend und nicht als pauschales 100-Prozent-Gate verwenden. Performance nur für stabile, relevante Baselines messen.

## Acceptance Criteria

Beide Testpläne sind über geteilte Schemes ausführbar; CI führt Fast bei normalen Änderungen und Full in einem dokumentierten Release- oder manuellen Pfad aus; Testergebnisse und Coverage werden als Artefakte bereitgestellt; ein klarer fehlgeschlagener Test blockiert den jeweiligen Gate.
