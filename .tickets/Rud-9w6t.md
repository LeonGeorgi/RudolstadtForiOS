---
id: Rud-9w6t
status: closed
deps: []
links: []
created: 2026-07-11T08:04:47Z
type: bug
priority: 2
assignee: Leon Georgi
tags: [approved]
---
# Gespeicherte Konzerte im Dark Mode besser hervorheben


## Notes

**2026-07-11T08:04:59Z**

Im Dark Mode ist die hinterlegte Farbe gespeicherter Konzerte nur sehr schlecht erkennbar. Die Hervorhebung soll einen ausreichend deutlichen Kontrast bieten, ohne die bestehende Darstellung im Light Mode zu verschlechtern.

**2026-07-12T16:17:59Z**

Listenmodus verwendet im Dark Mode nun 24 % statt 12 % Akzentdeckkraft für gespeicherte Veranstaltungen; Light Mode bleibt unverändert. git diff --check erfolgreich. Kein Build, keine Tests und keine visuelle Simulatorprüfung ausgeführt.
