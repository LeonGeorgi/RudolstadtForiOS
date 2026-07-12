---
id: Rud-etm6
status: open
deps: []
links: []
created: 2026-07-11T07:07:18Z
type: task
priority: 2
assignee: Leon Georgi
tags: [needs-approval, ui, images]
---
# Bilder mit abweichenden Seitenverhältnissen korrekt darstellen

Die Bilddarstellung geht aktuell nicht zuverlässig mit Bildern um, deren Seitenverhältnis vom vorgesehenen Standardformat abweicht. Solche Bilder werden teilweise verzerrt oder ragen über den für sie vorgesehenen Bildbereich hinaus. Die betroffenen Bildansichten sollen geprüft und so angepasst werden, dass beliebige Seitenverhältnisse konsistent, ohne Verzerrung und innerhalb der vorgesehenen Layoutgrenzen dargestellt werden.

## Acceptance Criteria

- Bilder werden unabhängig von ihrem ursprünglichen Seitenverhältnis nicht gestreckt oder anderweitig verzerrt.
- Bildinhalte ragen nicht über den vorgesehenen Bildbereich hinaus.
- Für die jeweiligen Ansichten ist bewusst und konsistent festgelegt, ob Bilder zugeschnitten (Fill) oder vollständig mit möglichem Leerraum (Fit) dargestellt werden.
- Hochformatige, quadratische und besonders breite Testbilder werden in den betroffenen Ansichten korrekt dargestellt.
- Die Lösung berücksichtigt unterschiedliche Gerätegrößen und Dynamic Type, soweit dies das umgebende Layout betrifft.
