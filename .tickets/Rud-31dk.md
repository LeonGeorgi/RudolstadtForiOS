---
id: Rud-31dk
status: closed
deps: []
links: []
created: 2026-07-20T13:38:46Z
type: task
priority: 1
assignee: Leon Georgi
tags: [approved]
---
# Künstlerdetail: Quadratischer Full-Bleed-Hero mit Namensoverlay

## Notes

**2026-07-20T13:43:58Z**

Implementiert: Full-Bleed-Hero auf dem iPhone ist 1:1; Inset-Variante bleibt 8:7. Künstlername liegt unten links in .title.bold() als separates, normal scrollendes Overlay über einem unteren Kontrastgradienten und wird im Inhaltsheader nicht doppelt gerendert. Sichtbarkeits-Callback wurde auf den Hero-Namen verlagert, damit Navigationstitel und Scroll-Edge-Effekt weiterhin korrekt übernehmen. iPad, Querformat und Accessibility behalten Inline-Bild und -Titel. Swift-Parse und git diff --check erfolgreich; visueller Screenshot-Check ausstehend.
