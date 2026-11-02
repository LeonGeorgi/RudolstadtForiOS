# Öffentliche Begleitseiten

Statische Download-, Support- und Datenschutzseiten mit Künstler-Linkvorschauen.
`website/` enthält die Quelldateien. `python3 scripts/website/build.py` kopiert
die öffentlichen Dateien und erzeugt Künstler-Metadaten in `artifacts/website/`.
Dieser von Git ausgeschlossene Ausgabeordner wird von der GitHub Action
**Website** in den separaten Branch `website-deploy` übertragen. Cloudflare
Workers Static Assets veröffentlicht anschließend diese fertigen Dateien.
Der Generator benötigt nur Python 3.10+ mit der
Standardbibliothek; weder App-Build noch Netzwerkzugriff sind erforderlich.
Die ausgelieferte Website benötigt keinen Worker-Code und keine Datenbank.
Diese README wird nicht in die Ausgabe kopiert.

`rudolstadt/index.html` enthält zunächst nur die App-Identität, einen
App-Store-Downloadbutton und Links zu Support und Datenschutz. Die bestehenden
Seiten und deren URLs bleiben erhalten. Künstlerlinks zeigen dieselbe sichtbare
Downloadseite mit eigenen Metadaten im HTML-Kopf. Ein Google-Play-Link wird ergänzt,
sobald die Android-App veröffentlicht ist.

`rudolstadt/app-icon.png` ist ein PNG-Export des aktuell in Xcode verwendeten
Icons aus `iosApp/Shared/Resources/Rudolstadt.icon` (Icon Composer, iOS,
Darstellung `Default`, 512 × 512 Pixel). Die alten Bilder aus
`AppIcon.appiconset` werden für die Website nicht verwendet.

`rudolstadt/app-store-badge-de.svg` ist Apples unverändertes deutsches Download-Badge,
lokal eingebunden mit 48 Pixeln Höhe und ursprünglichem Seitenverhältnis.
Quelle: [Apple Marketing Tools](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/de-de?size=250x83).
Die [App-Store-Marketingrichtlinien](https://developer.apple.com/app-store/marketing/guidelines/)
beschreiben Mindestgröße und Freiraum.

## Gestaltung der Begleitseiten

`support.html` und `privacy.html` verwenden das gemeinsame `site.css`. Die
responsive Gestaltung entspricht Version 2 der Sketch-Entwürfe und greift
Farben, Typografie, Trennlinien und Button-Radien von `leongeorgi.de` auf.
Source Sans 3 wird aus `fonts/SourceSans3-wght.ttf` lokal geladen; die zugehörige
SIL Open Font License liegt in `fonts/OFL.txt`. Es gibt keine externe
Schriftanfrage und kein JavaScript für Navigation oder Inhaltsverzeichnis.
Die Datenschutzabschnitte und deren Aktualisierungsdatum bleiben erhalten.

## Künstlerlinks

Neue Künstlerlinks verwenden
`https://festival.leongeorgi.de/rudolstadt/<jahr>/artists/<id>`.
Die Apps akzeptieren zusätzlich die bisherigen Links unter
`https://rudolstadt.leongeorgi.de/<jahr>/artists/<id>`.

Der Build liest `*_rudolstadt_data.json` sowie `*_archive.json` aus
`shared/src/commonMain/resources/FestivalBackup/`. Bei derselben Jahreszahl hat
das Live-Format Vorrang. Verborgene oder unbenannte Einträge werden ausgelassen.
Aktuell entstehen 881 Vorschauen für 2019 und 2022–2026.

Für jeden öffentlichen Eintrag entsteht beispielsweise
`artifacts/website/rudolstadt/2026/artists/67.html`. Cloudflare liefert diese Datei
unter dem geteilten Link ohne `.html` direkt mit HTTP 200 aus. Ein abschließender
Schrägstrich wird auf diese kanonische URL normalisiert; Jahr und ID bleiben
erhalten. Die früheren pauschalen `_redirects`-Regeln entfallen, weil sie die
Künstler-Metadaten durch die allgemeine Downloadseite ersetzen würden.

Die HTML-Dateien enthalten Titel, Kurzbeschreibung, kanonische URL sowie Open-Graph-
und Twitter-Card-Metadaten. Namen und Beschreibungen werden für HTML maskiert;
HTML-Markup wird aus Beschreibungen entfernt und längerer Text gekürzt.
Die sichtbare Seite wird aus `rudolstadt/index.html` übernommen. Stylesheet, Icon
und Footer-Links sind absolut zur Domain-Wurzel angegeben.

Bild-URLs verweisen direkt auf die öffentlichen Festivalfotos (aktuelle und
archivierte Bildpfade). Der Build kopiert oder prüft diese externen Fotos nicht.
Fehlende Bildangaben und bekannte Platzhalter verwenden das App-Icon. Wird ein
Festivalfoto später vom Ursprungsserver entfernt, muss seine Quelle in den
gebündelten Daten korrigiert werden. Bereits geteilte Vorschauen können von
Messengern zwischengespeichert sein; Darstellung und Abrufzeit bestimmt der Client.
Für 2019 wird vorerst ebenfalls das App-Icon verwendet: Mehrere geprüfte alte
Bild-URLs leiteten am 02.11.2026 auf die Festival-Startseite statt auf Fotos weiter.
Diese Ausnahme steht in `ARCHIVE_IMAGE_FALLBACK_YEARS` im Generator.

Unbekannte oder verborgene Künstlerlinks zeigen über `rudolstadt/404.html`
weiterhin die Downloadoberfläche, aber mit HTTP 404 und ohne Künstler-Metadaten.
Die Zuordnungsdateien für die Apps werden unverändert mitkopiert.

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

Die Datei `wrangler.jsonc` im Quellbranch `master` konfiguriert lokale Vorschau
und direkte Deployments mit `artifacts/website/` als Asset-Verzeichnis.
Für die automatische Veröffentlichung verwendet Cloudflare stattdessen den
generierten Branch `website-deploy` mit folgendem Inhalt:

```text
wrangler.jsonc     # Gleicher Worker, assets.directory: ./website, kein build-Eintrag
website/          # Fertige HTML-Dateien, CSS, Bilder, _headers und .well-known
```

Der Workflow `.github/workflows/website.yml` läuft auf einem normalen
Ubuntu-Runner bei Änderungen an Website, Website-Werkzeugen, Wrangler-Konfiguration
oder Rudolstadt-Festivaldaten auf `master`. Über **Actions → Website → Run workflow**
auf `master` kann er manuell gestartet werden. Er führt Tests und Generator aus
und ruft `scripts/website/publish.sh` auf. Das Skript übernimmt ausschließlich die
erzeugten öffentlichen Dateien, einschließlich `.well-known`, in einen eigenen
Git-Worktree und pusht den Deployment-Branch ohne Force-Push. Unveränderte Ausgabe
erzeugt keinen neuen Commit und damit kein weiteres Cloudflare-Deployment.

Der Workflow benötigt nur das eingebaute `GITHUB_TOKEN` mit `contents: write`,
keinen zusätzlichen Cloudflare-Schlüssel. Die Veröffentlichung erfolgt nur aus
`master`; Pull Requests testen den Generator über **Data tooling checks**.
Es werden keine zusätzlichen Actions-Artefakte gespeichert.

Cloudflare führt auf `website-deploy` keinen Generator und keinen App-Build aus.
Die bestehende Cloudflare-Pipeline für Repository-Checkout und Wrangler-Upload
verbraucht weiterhin etwas Pipeline-Zeit. `_headers` und
`not_found_handling: "404-page"` bleiben für App-Zuordnungen und Download-Fallback
aktiv.

1. Die Quelländerungen auf GitHub in `master` veröffentlichen und den Workflow
   **Website** erfolgreich durchlaufen lassen. Er legt `website-deploy` beim
   ersten Lauf an. Dieser Branch muss existieren, bevor er in Cloudflare
   ausgewählt werden kann.
2. Projektname: `festival-leongeorgi`. Root directory: Repository-Stamm
   (leer lassen). Unter **Settings → Build → Branch control** den
   **Production branch auf `website-deploy`** umstellen und **Enable Preview
   Builds deaktiviert** lassen, damit `master` keine zusätzlichen Cloudflare-
   Vorschau-Builds startet. Unter Build Configuration **Build command leer**
   lassen; Deploy command: `npx wrangler deploy`. Ein zuvor eingetragener
   Python-Build-Befehl muss entfernt werden. Danach für `website-deploy` einen
   ersten Build starten. [Cloudflare Branch control](https://developers.cloudflare.com/workers/ci-cd/builds/build-branches/)
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
dadurch nicht ausgeführt. Der Custom-Build-Eintrag in `wrangler.jsonc` erzeugt
die Dateien lokal vorab und beobachtet Vorlagen sowie Festivaldaten. Für eine
Prüfung ohne Veröffentlichung: `npx wrangler deploy --dry-run`.

Die Tests prüfen HTML-Maskierung, Bildpfade, ausgeblendete Künstler,
alte Jahresformate, unveränderte Downloadoberfläche und App-Zuordnungsdateien.
Ein lokales Git-Remote prüft zusätzlich die erste Veröffentlichung, Updates,
Löschen veralteter Dateien und unveränderte Ausgabe ohne zusätzlichen Commit:

```sh
python3 -m unittest discover -s scripts/website -p '*_test.py'
```

Für eine einfache lokale Vorschau kann erst `python3 scripts/website/build.py`
und dann `python3 -m http.server 8080 --directory artifacts/website` gestartet und
`http://localhost:8080/rudolstadt/` geöffnet werden. Dieser einfache Server wertet
Cloudflares Header und URL-Normalisierung nicht aus; Künstlerseiten sind dort
direkt unter `/rudolstadt/2026/artists/67.html` erreichbar. Für echte geteilte
Künstlerpfade ohne `.html` die Wrangler-Vorschau verwenden.

## Veröffentlichungsstand und offene Schritte

- Cloudflare-DNS, Worker und Custom Domain sind eingerichtet. Die iOS-Links
  wurden auf einem iPhone getestet.
- Android wird zunächst mit einer lokal signierten APK ohne Play Store getestet.
  Die Downloadseite bietet bislang nur den App-Store-Link für iOS an.
- Künstler-Vorschauen und GitHub-Workflow sind lokal vorbereitet. Vor der
  Aktivierung Änderungen veröffentlichen, den Workflow ausführen und Cloudflare
  wie oben auf `website-deploy` umstellen. Danach neue Künstlerlinks in den
  gewünschten Messengern testen.
- Die bisherigen Links benötigen für das direkte Öffnen in der App weiterhin
  eine eigene Zuordnungsdatei an der bisherigen Domain.
