# Öffentliche Spendensummen

Der eigenständige Workflow **Update donation totals** berechnet Spenden pro
Kalenderjahr und Kaufwährung. Er läuft täglich um 17:23 UTC und kann unter
Actions manuell gestartet werden. Ausführung und Veröffentlichung sind auf den
Standardbranch `master` des Originalrepositories beschränkt. Bei öffentlichen
Repositories deaktiviert GitHub Zeitpläne nach 60 Tagen ohne Repositoryaktivität;
in diesem Fall den Zeitplan unter Actions wieder aktivieren.

## Einmalige Einrichtung

1. In App Store Connect unter **Users and Access → Integrations → App Store Connect
   API → Team Keys** einen Team-Key mit der Rolle **Sales and Reports** anlegen.
   Ein individueller API-Key unterstützt den Berichtsdownload nicht.
2. Unter [Repository → Settings → Secrets and variables → Actions](https://github.com/LeonGeorgi/RudolstadtForiOS/settings/secrets/actions)
   diese **Repository Secrets** eintragen:

   | Secret | Inhalt |
   | --- | --- |
   | `ASC_KEY_ID` | Key-ID des Team-Keys |
   | `ASC_ISSUER_ID` | Issuer-ID aus App Store Connect |
   | `ASC_PRIVATE_KEY` | Vollständiger Inhalt der `.p8`-Datei, einschließlich PEM-Kopf/-Fuß und echten Zeilenumbrüchen |
   | `ASC_VENDOR_NUMBER` | Vendor-Nummer aus **Payments and Financial Reports** |

3. Den Workflow auf `master` übernehmen und **Actions → Update donation totals →
   Run workflow** starten. Der erste erfolgreiche Lauf erstellt automatisch den
   unabhängigen Branch `donation-data`. Der GitHub-Workflow benötigt Schreibrechte
   für Repositoryinhalte; Branchregeln dürfen den Bot-Push nach `donation-data`
   nicht verhindern.
4. Ergebnisadresse nach dem ersten erfolgreichen Lauf:
   `https://raw.githubusercontent.com/LeonGeorgi/RudolstadtForiOS/donation-data/donations.json`

Der bestehende Screenshot-Branch und die GitHub-Pages-Veröffentlichung werden
nicht verändert. Die App-Anzeige der Gesamtsumme ist ein separater Schritt.

## Öffentliches Format

Beispiel mit **erfundenen** Werten; diese Datei wird nicht vorab veröffentlicht:

```json
{
  "2025": {
    "EUR": "123.45",
    "USD": "20.00"
  },
  "2026": {
    "EUR": "80.00",
    "JPY": "1500.00"
  }
}
```

Die einzige öffentliche Datei ist `donations.json`. Sie enthält ausschließlich
Jahreszahlen, ISO-Währungscodes und Dezimalbeträge als Strings. Es gibt keine
Kaufanzahlen, Produktaufschlüsselungen, Länder, persönlichen Kennungen oder
Zeitstempel einzelner Käufe. Leere Jahresobjekte bedeuten, dass in den vollständig
abgerufenen Berichten keine passenden Spenden gefunden wurden. Nicht aufgeführte
Währungen werden nicht künstlich ergänzt. Frühere Commits enthalten ausschließlich
frühere Fassungen dieser Jahressummen.

## Bedeutung und Berechnung

- Quelle ist Apples **Summary Sales Report**, Version `1_0`.
- Berücksichtigt werden ausschließlich `donation200`, `donation500`,
  `donation1000`, `donation2000` und `donation5000` der App `1629927812`.
  Die über Apples App-API geladene Parent-SKU grenzt gleichnamige Produkte anderer
  Apps desselben Teams aus.
- Grundlage ist **Customer Price**, also der von Apple berichtete Kaufpreis vor
  Abzug von Provision und Steuern, nicht **Developer Proceeds**. Es erfolgt keine
  Währungsumrechnung und keine Rundung über die Quelldaten hinaus.
- Volle Erstattungen reduzieren die Summe. Apple liefert dafür negative Units und
  negative Customer Prices; das Vorzeichen wird nur einmal angewendet. Eine
  Null-Stückzahl mit einem Betrag wird zur manuellen Prüfung abgewiesen, statt
  diese unklaren Anpassungen als null zu behandeln.
- Zuordnung nach Kalenderjahr des **Apple-Berichts**, nicht nach Apples
  Geschäftsjahr. Eine im Folgejahr berichtete Erstattung reduziert das Folgejahr;
  die Originalspende wird nicht rückwirkend umgebucht.
- Die Historie beginnt mit dem Veröffentlichungsjahr der App, 2022. Ältere
  abgeschlossene Jahre werden mit Jahresberichten ermittelt. Für neuere Zeiträume
  werden Monatsberichte und anschließend Tagesberichte verwendet. Die Zeiträume
  sind lückenlos und überlappen nicht. Am Jahres-/Monatswechsel werden noch nicht
  verfügbare Sammelberichte zunächst durch kleinere Berichte ersetzt.
- Es bleiben zwei Tage Abstand zum aktuellen Datum im Berichtszeitraum
  `America/Los_Angeles`. Die laufende Jahressumme ist daher vorläufig und wird bei
  jedem Lauf aus den Berichten neu berechnet, nicht zu einem gespeicherten Zähler
  addiert. Über Rohdaten oder Dateien werden keine Zwischensummen veröffentlicht.
- Jahresberichte bleiben laut Apple zehn Jahre verfügbar. Ein Lauf bricht ab,
  wenn benötigte Berichte fehlen oder abgelaufen sind. Es wird keine teilweise
  Historie als vollständige Summe ausgegeben. Langfristig muss der Startzeitraum
  vor Ablauf der Berichtsaufbewahrung überprüft werden.

## Fehler und Vertraulichkeit

Apple-Berichte werden im Arbeitsspeicher verarbeitet. Sie werden weder als
Artefakt oder Cache hochgeladen noch ins Repository oder in Logs geschrieben.
Nur Apples explizite Antwort „There were no sales“ zählt als leerer Zeitraum.
Ein allgemeines HTTP 404, Authentifizierungsfehler oder ungültige Berichtszeilen
brechen den Lauf ab. Die zuletzt veröffentlichten Werte bleiben dann erhalten.
Auch ein erster Lauf veröffentlicht bei fehlenden Secrets keine Beispieldaten.

## Lokale Prüfung

Offline, ohne Apple-Key und ohne Netzwerk:

```sh
python3 -m unittest discover -s scripts/donations -p '*_test.py'
bash -n scripts/donations/publish_donations.sh
```

Ein echter Abruf benötigt Python 3.12 und die vier Umgebungsvariablen entsprechend
den oben genannten Secrets:

```sh
python3 -m venv .venv-donations
.venv-donations/bin/python -m pip install -r scripts/donations/requirements.txt
.venv-donations/bin/python scripts/donations/update_donations.py \
  --output artifacts/donations/donations.json
```

## Quellen

- [Apple: Summary Sales Report, inklusive Erstattungsbeispiel](https://developer.apple.com/help/app-store-connect/reference/reporting/summary-sales-report)
- [Apple: Berichtsverfügbarkeit und Aufbewahrung](https://developer.apple.com/help/app-store-connect/reference/reporting/sales-and-trends-reports-availability)
- [Apple: Sales and Trends API](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-salesreports)
- [Apple: Team-Keys für Sales and Finance](https://developer.apple.com/documentation/appstoreconnectapi/sales-and-finance)
- [GitHub: Geplante Workflows und Verzögerungen](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)
