# Entwicklungswerkzeuge

Alle Befehle werden im Projektstamm ausgeführt. Die Werkzeuge liegen außerhalb der
App-Targets; ihre relativen Datenpfade beziehen sich auf dieses Repository.

| Ordner | Aufgabe |
| --- | --- |
| `data/` | Archiv- und Ludwigsburg-Import, kuratierte Planpositionen, Musiklink-Suche |
| `analysis/` | Künstler-Embeddings, Ähnlichkeitsanalysen, Plots und Ressourcenexport |
| `ios/` | Kotlin-Framework für Xcode bauen und App-Store-Screenshots aufnehmen |
| `android/` | Android-App bauen, Emulator starten und Screenshots aufnehmen |

## Datenpflege

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

## Apple-Werkzeuge

`ios/build-apple-framework.sh` wird von Xcode mit dessen Build-Umgebung aufgerufen
und baut das passende `RudolstadtCore.framework`. Für manuelle Gradle-Aufrufe siehe
[Projekt-README](../README.md). Die [Screenshot-Anleitung](../.maestro/app-store-screenshots/README.md)
beschreibt `ios/capture-app-store-screenshots.sh`; Ausgaben liegen standardmäßig
unter `artifacts/screenshots/app-store/`.

## Android-Screenshots

`android/capture-screenshots.sh` verwendet eine gebaute Debug-APK und einen
dedizierten, gestarteten Emulator. Maestro nimmt die vier Hauptansichten auf
Deutsch und Englisch in Hell und Dunkel auf. Der Workflow **Android Screenshots**
baut einmal und verwendet die APK für Telefon und Tablet. Aufnahmen und Diagnosen
werden als getrennte Artefakte hochgeladen. Details und lokale Aufrufe stehen im
[Android-README](../androidApp/README.md#screenshots-in-github-actions).

`prepare_readme_screenshots.py` prüft alle 32 Android-Aufnahmen, erstellt kleine
Vorschaubilder und die Galerie. `publish-readme-screenshots.sh` aktualisiert danach
den separaten Branch `screenshots`, dessen stabile Bildlinks die Haupt-README nutzt.
