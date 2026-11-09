# Früherer CloudKit-Profilabgleich

Seit dem Firebase-Umstieg am 4. November 2026 ist CloudKit aus der aktiven App entfernt.
Es gibt keine CloudKit-Engines, Freigabedialoge, Benachrichtigungen oder Entitlements mehr.
Die App liest und verändert auch keine bisherigen Daten oder Freigaben in CloudKit.

Ausschließlich vorhandene lokale Profile einschließlich privater Notizen werden in den
neuen Abgleich übernommen. Das frühere Cacheformat bleibt dafür lesbar; enthaltene
Systemfelder werden als opake Daten gesichert und nicht ausgewertet.

Aktuelle Architektur und Einrichtung:
[Firebase-Entscheidung](../adr/0002-firebase-friends.md) und
[Profilabgleich und Freunde](../firebase-friends.md).
