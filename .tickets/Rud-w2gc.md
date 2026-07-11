---
id: Rud-w2gc
status: open
deps: [Rud-8z2c]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-sa0w
tags: [needs-approval, tests, api, contract-tests, data-conversion, fixtures, effort-medium, confidence-high]
---
# API-Decoding und Datenkonvertierung mit Contract-Fixtures absichern

API-Modelle und DataConverter gegen kleine gezielte Fixtures sowie die gebündelten Festivaldaten absichern, damit Schemaänderungen und fehlerhafte Referenzen früh sichtbar werden.

## Design

Parametrisierte Tests für Kategorien, HTML-Zeichen, Datumsformate und fehlende Referenzen ergänzen. Einen Contract-Test über die gebündelte 2026-JSON-Datei ausführen und relevante ID-Beziehungen sowie Konvertierungsergebnisse validieren.

## Acceptance Criteria

Bekannte und unbekannte Kategorien, Zeitformate, HTML-Referenzen und Fallback-Areas sind getestet; fehlende Artist-, Stage- und Tag-Referenzen haben explizit getestetes Verhalten; das gebündelte Festival-Backup decodiert und konvertiert vollständig unter dokumentierten Integritätsprüfungen.
