# Entwicklungswerkzeuge

Alle Befehle werden im Projektstamm ausgeführt. Die Werkzeuge liegen außerhalb der
App-Targets; ihre relativen Datenpfade beziehen sich auf dieses Repository.

| Ordner | Aufgabe |
| --- | --- |
| `data/` | Archiv- und Ludwigsburg-Import, kuratierte Planpositionen, Musiklink-Suche |
| `analysis/` | Künstler-Embeddings, Ähnlichkeitsanalysen, Plots und Ressourcenexport |
| `ios/` | Kotlin-Framework für Xcode bauen und App-Store-Screenshots aufnehmen |
| `android/` | Android-App bauen, Emulator starten und Screenshots aufnehmen |
| `website/` | Statische Künstler-Linkvorschauen aus den gebündelten Festivaldaten erzeugen |

## Datenpflege

Die Website benötigt keine Python-Pakete: `python3 scripts/website/build.py`
erzeugt die veröffentlichbaren Dateien unter `artifacts/website/`. Ablauf,
lokale Vorschau und Cloudflare-Einstellungen stehen in der
[Website-Anleitung](../website/README.md). Die GitHub Action **Website** generiert
die Ausgabe auf `master` und überträgt sie mit `website/publish.sh` in den
Deployment-Branch `website-deploy`; Cloudflare veröffentlicht dessen fertige Dateien.

Die Python-Importer benötigen Python 3.10 oder neuer. Der Ludwigsburg-Import und
seine Tests benötigen zusätzlich `pypdf`; die Kartenvorschau verwendet `pdftoppm`
aus Poppler. Der Ruby-Linkfinder verwendet die Standardbibliothek; seine Tests
verwenden Minitest 5.25.5 (`gem install minitest -v 5.25.5 --no-document`).

```sh
python3 -m venv .venv-tools
.venv-tools/bin/python -m pip install -r scripts/requirements-data.txt
.venv-tools/bin/python -m unittest discover -s scripts/data -p '*_test.py'
ruby scripts/data/find_artist_music_links_test.rb
```

Importbefehle und Quellen sind unter [Festivaldaten](../docs/festival-data.md)
beschrieben, Linkfinder-Optionen unter [Musiklinks](../docs/artist-music-links.md).
Die mit dem Ludwigsburg-Importer verwendete kuratierte JSON-Datei bleibt direkt
neben dem Skript; sie enthält die geprüfte Prüfsumme des offiziellen Lageplans.

## Analysen

Analysen sind optionale Entwicklungswerkzeuge. Sie gehören nicht zum App-Build.
Sie lesen das gemeinsame Programm und schreiben nach `artifacts/artist-similarity/`.
Downloads und HTTP-Caches liegen unter `artifacts/cache/`. Die bereits exportierten,
mit der App ausgelieferten Ergebnisse liegen in `shared/src/commonMain/resources`.

Die vorhandenen Werkzeuge verwenden je nach Analyse NumPy, SciPy, scikit-learn,
Matplotlib, HDBSCAN, Pillow, PyTorch, Transformers und Sentence Transformers.
Dafür eine eigene Umgebung `.venv-analysis` mit Python 3.12 oder neuer verwenden:

```sh
python3.12 -m venv .venv-analysis
.venv-analysis/bin/python -m pip install -r scripts/requirements-analysis.txt
```

Die direkten Abhängigkeiten sind auf die Versionen der bisherigen Analysen
festgelegt. Für eine konkrete wiederholbare Auswertung zusätzlich den vollständigen
Umgebungsstand mit `python -m pip freeze` und die Modellrevision im Ergebnis sichern.
 Modellgewichte werden beim
ersten Gebrauch geladen; einige Analysen erwarten zuvor erzeugte Embeddings oder
manuell erstellte Referenzprofile. Frühere lokale Experimentdaten wurden nicht in
dieses Repository übernommen. Zum Fortsetzen vorhandener Analysen deren Dateien
nach `artifacts/artist-similarity/` übernehmen; in älteren Metadaten gespeicherte
relative Quellpfade müssen zur neuen Ablage passen.

Tests mit eingerichteter Analyseumgebung:

```sh
.venv-analysis/bin/python -m unittest discover -s scripts/analysis -p '*_test.py'
```

Der isolierte Zeitplan-Prototyp benötigt nur die Python-Standardbibliothek:

```sh
python3 -m unittest discover -s scripts/analysis -p 'benchmark_schedule_planner_test.py'
python3 scripts/analysis/benchmark_schedule_planner.py --seeds 10 --budgets 0.1 1
```

Er vergleicht die bisherige Greedy-Auswahl mit einer budgetierten
Branch-and-Bound-Suche auf Rudolstadt 2026 und dem fiktiven Debug-Festival.
Bewertungen und gespeicherte Konzerte sind reproduzierbar erzeugte Testprofile.
Bericht, Einzelmessungen und ausgewählte Konzerte stehen unter
`artifacts/planner-benchmark/`. Startheuristik, Suchgewinn, bewiesene Optimalität
und verbleibende Schranken werden getrennt ausgewiesen. Die Zeiten gelten für
Python auf dem ausführenden Rechner; die App wird nicht verändert.

`python3 scripts/analysis/compare_duration_weights.py` vergleicht auf denselben
Testprofilen vier Zielfunktionen: nur Bewertung, Bewertung mal Dauer sowie zwei
abgeschwächte Dauergewichtungen. Alle Varianten verwenden Bewertung² und sind
bei 60 Minuten gleich gewichtet. Der Bericht unter
`artifacts/planner-duration-weights/` zeigt Änderungen der Konzertauswahl und der
Hörzeit je Bewertungsstufe. Die Dauern von Rudolstadt 2026 sind geschätzt; das
Debug-Festival enthält explizite Dauern. Die gezielten Tests laufen mit
`python3 -m unittest discover -s scripts/analysis -p 'compare_duration_weights_test.py'`.

Die größere Operationsbudget-Simulation kombiniert Bewertungsanteile,
Herzenverteilungen, 0/2/6/12 gespeicherte Konzerte, Planungszeitpunkte und Seeds.
Standardmäßig entstehen 400 Szenarien mit jeweils 13 Budget-Checkpoints:

```sh
python3 scripts/analysis/simulate_planning_budgets.py
python3 scripts/analysis/plot_planning_budgets.py
```

Die Simulation selbst nutzt die Standardbibliothek. Für die unabhängige
Optimalitätsreferenz ist SciPy nötig (`--reference-seconds 0` deaktiviert sie);
die Grafiken benötigen Matplotlib und NumPy. Ergebnisse, Profile, Code-Hashes,
CSV und PNG/SVG stehen unter `artifacts/planner-simulation/`.
Eine Operation zählt eine Kandidatenprüfung in Startheuristik, Schrankenbau oder
Verzweigung; Datenaufbereitung und Sortierung liegen außerhalb dieses Budgets.
Checkpoints stammen aus demselben Suchlauf, sodass mehr Budget nie zu einem
schlechteren Score führt. Die Diagramme trennen absolute Zusatzscores und den
Anteil am unabhängig nachgewiesenen Optimum. Budgetkurven mit Referenzqualität
setzen eine aktivierte SciPy-Referenz voraus.

`compare_search_strategies.py` spielt die eingefrorenen Profile aus diesem
Versuch erneut ab und vergleicht die verbesserte Suche gegen die alten CSV-Werte:

```sh
python3 scripts/analysis/compare_search_strategies.py
python3 scripts/analysis/plot_search_comparison.py
```

Die neue Variante (`solve(..., strategy="repair")`) verwendet aktive Bitsets,
eine andere Verzweigungsreihenfolge, gültige Vervollständigungen der Teilpläne
und begrenzte Planreparaturen. Der Solver-Standard `baseline` bleibt als
Kontrollvariante erhalten. Beide beginnen mit denselben sechs Startheuristiken;
alle Kandidatenprüfungen der zusätzlichen Schritte zählen zum Budget.
Ergebnisse und PNG/SVG stehen unter `artifacts/planner-search-comparison/`.
Der Vergleich zählt auch Verschlechterungen und weist schwierige Profile sowie
die Seeds separat aus. Die Referenzoptima
werden ausschließlich zur Auswertung verwendet.

Die Beiträge der einzelnen Änderungen lassen sich getrennt prüfen:

```sh
python3 scripts/analysis/compare_search_strategies.py --strategies active-cover improved repair --maximum 100000 --output artifacts/planner-search-ablation
```

## Apple-Werkzeuge

`ios/build-apple-framework.sh` wird von Xcode mit dessen Build-Umgebung aufgerufen
und baut das passende `RudolstadtCore.framework`. Für manuelle Gradle-Aufrufe siehe
[Projekt-README](../README.md). Die [Screenshot-Anleitung](../docs/screenshots.md)
beschreibt `ios/capture-app-store-screenshots.sh`; Ausgaben liegen standardmäßig
unter `artifacts/screenshots/app-store/`.

## Android-Screenshots

Eine signierte APK ohne Play Store baut `android/build-release.sh`.
Schlüsselablage, Installation und App-Link-Test sind in der
[Release-Anleitung](android/RELEASE.md) beschrieben.

`android/capture-screenshots.sh` verwendet eine gebaute Debug-APK und einen
dedizierten, gestarteten Emulator. UI Automator nimmt die vier Hauptansichten auf
Deutsch und Englisch in Hell und Dunkel auf. Der Workflow **Android Screenshots**
baut einmal und verwendet die APK für Telefon und Tablet. Aufnahmen und Diagnosen
werden als getrennte Artefakte hochgeladen. Details und lokale Aufrufe stehen im
[Android-README](../androidApp/README.md#screenshots-in-github-actions).

`prepare_readme_screenshots.py` prüft alle 32 Android-Aufnahmen, erstellt kleine
Vorschaubilder und die Galerie. `publish-readme-screenshots.sh` aktualisiert danach
den separaten Branch `screenshots`, dessen stabile Bildlinks die Haupt-README nutzt.

## Screenshot-Tests

`ios/capture-app-store-screenshots.sh` führt den XCTest-Screenshot-Satz aus und
exportiert benannte PNG-Anhänge aus dem `xcresult`.
`android/capture-screenshots.sh` verwendet das separate UI-Automator-Testmodul
`androidScreenshotTests`. Beide erzeugen das Ausgabeformat der Galerie-Publisher.
Aufrufe und Voraussetzungen: [Screenshot-Automation](../docs/screenshots.md).
