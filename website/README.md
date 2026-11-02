# Öffentliche Begleitseiten

Statische Download-, Support- und Datenschutzseiten. Der Ordner `website/`
ist das Veröffentlichungsverzeichnis für Cloudflare Workers Static Assets.
Die Dateien benötigen keinen Build und keinen Zugriff auf Festivaldaten.
Wrangler wird nur zur lokalen Vorschau und Veröffentlichung verwendet;
die Website selbst benötigt keinen Worker-Code. `.assetsignore` schließt diese
Dokumentation von der Veröffentlichung aus.

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

Für Android liegt dort außerdem `/.well-known/assetlinks.json`, ebenfalls als
JSON ohne Weiterleitung. Sie enthält den Paketnamen
`de.leongeorgi.rudolstadt.android` und den SHA-256-Fingerabdruck des eigenen
Release-Zertifikats. Debug-APKs sind damit nicht für die Domain verifiziert.
Die signierte APK wird mit `scripts/android/build-release.sh` erzeugt;
siehe [Release-Anleitung](../scripts/android/RELEASE.md).
Falls später Play App Signing mit einem anderen App-Signaturschlüssel verwendet
wird, muss dessen Fingerabdruck zusätzlich in die Datei aufgenommen werden.

Bei installierter App kann das Betriebssystem einen Künstlerlink direkt in der
App öffnen, bevor die Website geladen wird. Das hängt auch vom Browser und den
Nutzereinstellungen ab. Eine im Browser eingegebene URL oder ein in Safari
bewusst als Website geöffneter Link kann weiterhin die Downloadseite zeigen.
Die Seite versucht nicht, installierte Apps zu erkennen. Nach einer Installation
muss der ursprüngliche Künstlerlink erneut geöffnet werden; eine automatische
Übernahme des Künstlerlinks aus dem App Store ist nicht vorgesehen.

## Cloudflare Workers einrichten

Die Datei `wrangler.jsonc` im Repository-Stamm konfiguriert einen reinen
Static-Assets-Worker namens `festival-leongeorgi` mit `website/` als
Asset-Verzeichnis. Die vorhandenen `_headers` und `_redirects` werden auch
von Workers Static Assets ausgewertet.

1. In Cloudflare unter Workers & Pages eine Anwendung über GitHub anlegen.
   Das Repository verbinden und als Produktionsbranch `master` wählen.
   Die Website-Dateien und `wrangler.jsonc` müssen zuvor auf GitHub liegen.
2. Projektname: `festival-leongeorgi`. Root directory: Repository-Stamm
   (leer lassen). Build command: leer lassen. Deploy command:
   `npx wrangler deploy`. Preview command: `npx wrangler preview`.
3. Nach dem Deployment im Worker unter Settings → Domains & Routes → Add →
   Custom Domain die Domain `festival.leongeorgi.de` hinzufügen. Dafür muss
   `leongeorgi.de` bei Cloudflare als aktive Zone eingerichtet sein. Cloudflare
   erstellt DNS und Zertifikat für die Worker-Domain; es wird kein Pages-CNAME
   bei DigitalOcean mehr benötigt.
4. Nach der Veröffentlichung die AASA-Datei auf Status 200, JSON-Content-Type
   und ausbleibende Weiterleitung prüfen. Einen Künstlerlink auf einem echten
   iPhone aus Nachrichten oder Notizen mit der aktualisierten App testen.
5. Ohne installierte App denselben Künstlerlink auf die Downloadseite und den
   App-Store-Button prüfen. Der App-Store-Link verwendet die vorhandene App-ID
   `1629927812`.

Für eine lokale Vorschau einschließlich Künstlerpfaden und HTTP-Headern kann
im Repository-Stamm `npx wrangler dev` gestartet werden. Ein Deployment wird
dadurch nicht ausgeführt. Für eine Prüfung ohne Veröffentlichung:
`npx wrangler deploy --dry-run`.

Für eine einfache lokale Vorschau nur der Seite kann im Repository-Stamm
`python3 -m http.server 8080 --directory website` gestartet und
`http://localhost:8080/rudolstadt/` geöffnet werden. Dieser einfache Server wertet
`_redirects` und `_headers` nicht aus; die Künstlerpfade benötigen die
Wrangler-Vorschau oder die veröffentlichte Website.

## Veröffentlichungsstand und offene Schritte

- Cloudflare-DNS, Worker und Custom Domain sind eingerichtet. Die iOS-Links
  wurden auf einem iPhone getestet.
- Android wird zunächst mit einer lokal signierten APK ohne Play Store getestet.
  Die Downloadseite bietet bislang nur den App-Store-Link für iOS an.
- Die bisherigen Links benötigen für das direkte Öffnen in der App weiterhin
  eine eigene Zuordnungsdatei an der bisherigen Domain.
