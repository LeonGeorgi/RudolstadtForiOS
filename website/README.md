# Öffentliche Begleitseiten

Statische Download-, Support- und Datenschutzseiten. Der Ordner `website/`
ist direkt das Veröffentlichungsverzeichnis für Cloudflare Pages; ein Build,
Node.js, Python oder ein Zugriff auf Festivaldaten ist dafür nicht erforderlich.

`rudolstadt/index.html` enthält zunächst nur die App-Identität, einen
App-Store-Downloadbutton und Links zu Support und Datenschutz. Die bestehenden
Seiten und deren URLs bleiben erhalten. Es werden keine einzelnen Künstlerseiten
erzeugt. Ein Google-Play-Link wird ergänzt, sobald die Android-App veröffentlicht ist.

`rudolstadt/app-icon.png` ist ein PNG-Export des aktuell in Xcode verwendeten
Icons aus `iosApp/Shared/Resources/Rudolstadt.icon` (Icon Composer, iOS,
Darstellung `Default`, 512 × 512 Pixel). Die alten Bilder aus
`AppIcon.appiconset` werden für die Website nicht verwendet.

`rudolstadt/app-store-badge-de.svg` ist Apples unverändertes deutsches Download-Badge,
lokal eingebunden mit 48 Pixeln Höhe und ursprünglichem Seitenverhältnis.
Quelle: [Apple Marketing Tools](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/de-de?size=250x83).
Die [App-Store-Marketingrichtlinien](https://developer.apple.com/app-store/marketing/guidelines/)
beschreiben Mindestgröße und Freiraum.

## Künstlerlinks

Neue Künstlerlinks verwenden
`https://festival.leongeorgi.de/rudolstadt/<jahr>/artists/<id>`.
Die Apps akzeptieren zusätzlich die bisherigen Links unter
`https://rudolstadt.leongeorgi.de/<jahr>/artists/<id>`.

`_redirects` liefert für Künstlerlinks mit und ohne abschließenden Schrägstrich
dieselbe Downloadseite aus (Status 200). Es findet keine Browser-Weiterleitung
statt, sodass Jahr und Künstler-ID in der ursprünglichen URL erhalten bleiben.
Stylesheet, Icon und Footer-Links sind deshalb absolut zur Domain-Wurzel angegeben.

Die Apple-Zuordnungsdatei liegt direkt an der Domain-Wurzel:

- `https://festival.leongeorgi.de/.well-known/apple-app-site-association`
  mit der im Xcode-Projekt eingetragenen Team-ID und Bundle-ID sowie auf
  `/rudolstadt/*/artists/*` begrenzten Pfaden. `_headers` setzt
  `Content-Type: application/json`. Die Datei darf nicht weitergeleitet werden.

Bei installierter App kann das Betriebssystem einen Künstlerlink direkt in der
App öffnen, bevor die Website geladen wird. Das hängt auch vom Browser und den
Nutzereinstellungen ab. Eine im Browser eingegebene URL oder ein in Safari
bewusst als Website geöffneter Link kann weiterhin die Downloadseite zeigen.
Die Seite versucht nicht, installierte Apps zu erkennen. Nach einer Installation
muss der ursprüngliche Künstlerlink erneut geöffnet werden; eine automatische
Übernahme des Künstlerlinks aus dem App Store ist nicht vorgesehen.

## Cloudflare Pages einrichten

1. Das Repository verbinden, als Produktionsbranch den gewünschten Branch wählen.
2. Kein Framework und keinen Build-Befehl konfigurieren; Veröffentlichungsverzeichnis:
   `website` relativ zum Repository-Stamm.
3. Die benutzerdefinierte Domain `festival.leongeorgi.de` hinzufügen und die von
   Cloudflare angezeigte DNS-Konfiguration beim Domain-Anbieter übernehmen.
4. Nach der Veröffentlichung die AASA-Datei auf Status 200, JSON-Content-Type
   und ausbleibende Weiterleitung prüfen. Einen Künstlerlink auf einem echten
   iPhone aus Nachrichten oder Notizen mit der aktualisierten App testen.
5. Ohne installierte App denselben Künstlerlink auf die Downloadseite und den
   App-Store-Button prüfen. Der App-Store-Link verwendet die vorhandene App-ID
   `1629927812`.

Für eine lokale Vorschau der Seite kann im Repository-Stamm
`python3 -m http.server 8080 --directory website` gestartet und
`http://localhost:8080/rudolstadt/` geöffnet werden. Dieser einfache Server wertet
`_redirects` und `_headers` nicht aus; die Künstlerpfade benötigen Cloudflare Pages
oder eine Cloudflare-kompatible Vorschau.

## Noch ausstehend

- Hosting, DNS, Veröffentlichung der aktualisierten Apps und der Gerätetest
  sind noch nicht eingerichtet beziehungsweise durchgeführt.
- Für Android fehlt `/.well-known/assetlinks.json` mit Paketname
  `de.leongeorgi.rudolstadt.android` und dem SHA-256-Fingerabdruck des tatsächlichen
  Release-Signaturzertifikats (bei Play App Signing: App-Signaturschlüssel).
  Die Datei wird erst mit dem verifizierten Fingerabdruck ergänzt; bis dahin
  ist die neue Domain für Android nicht verifiziert.
- Die bisherigen Links benötigen für das direkte Öffnen in der App weiterhin
  eine eigene Zuordnungsdatei an der bisherigen Domain.
