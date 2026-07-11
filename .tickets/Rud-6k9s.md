---
id: Rud-6k9s
status: closed
deps: []
links: []
created: 2026-07-11T08:50:39Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-gqey
tags: [approved, tests, test-plans, ci, coverage, unit-tests, effort-small, confidence-high]
---
# Fast-Testplan und Unit-Test-CI für Push und Pull Requests einführen

Einen sofort nutzbaren Fast-Testpfad für die vorhandenen Unit-, Contract- und lokalen Service-Tests schaffen und bei normalen Repository-Änderungen automatisch ausführen.

## Design

Einen geteilten Fast-Testplan am bestehenden Unit-Tests-Scheme verankern. Einen separaten GitHub-Actions-Workflow für Push, Pull Request und manuelle Ausführung anlegen; laufende ältere Runs abbrechen; normalen Simulator-Code-Signing-Pfad verwenden; xcresult, Build-Log und Coverage als Artefakte bereitstellen. Den bestehenden Screenshot-Workflow nicht verändern.

## Acceptance Criteria

Der Fast-Testplan ist über das geteilte Unit-Tests-Scheme lokal ausführbar; Pushes und Pull Requests starten automatisch die Fast-Suite; fehlgeschlagene Tests lassen den Workflow fehlschlagen; Testresultat, Log und Coverage werden auch bei Fehlern als Artefakte hochgeladen; Rud-rzvz bleibt auf den späteren Full-/Release-Pfad fokussiert.

## Notes

**2026-07-11T08:54:23Z**

Implementiert: Geteilter Testplan „Fast Tests“ enthält ausschließlich das Unit-Tests-Target, aktiviert Coverage und ist als Standardplan am geteilten Scheme „Unit Tests“ verankert. Neuer separater Workflow ios-fast-tests.yml läuft bei push, pull_request und workflow_dispatch auf macos-26, wählt einen verfügbaren iOS-26-Simulator, verwendet normales Simulator-Signing, bricht ältere Läufe derselben Ref ab und lädt xcresult, Rohlog und Coverage unabhängig vom Testergebnis als Artefakt hoch. Rud-rzvz wurde auf den späteren Full-/Release-Pfad fokussiert und hängt nun von Rud-6k9s ab; der bestehende Screenshot-Workflow blieb unberührt. Verifikation: JSON-, XML- und YAML-Parser erfolgreich, git diff --check erfolgreich, xcodebuild -showTestPlans erkennt „Fast Tests“. Die vollständige Suite wurde gemäß AGENTS.md nicht lokal gestartet; die End-to-End-Ausführung des neuen GitHub-Workflows erfolgt mit dem ersten Push.
