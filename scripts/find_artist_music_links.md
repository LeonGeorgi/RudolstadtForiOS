# Apple-Music-Linkfinder

`find_artist_music_links.rb` sucht ohne AI für jeden Eintrag aus den Festivaldaten
einen plausiblen Apple-Music-Link. Es verwendet die Quellen in dieser Reihenfolge:

1. Apple-Music-Links auf der im Festivaldatensatz hinterlegten Website
2. eindeutige MusicBrainz-Künstler und deren Apple-Beziehungen
3. Apples öffentliche Künstler- und Albumssuche

Das Skript übernimmt keinen Treffer allein aufgrund eines gleichen Namens. Jeder
Kandidat erhält einen nachvollziehbaren Score und eine Liste seiner Belege.

## Ausführen

Vollständiger Lauf:

```sh
ruby scripts/find_artist_music_links.rb
```

Gezielter Probelauf:

```sh
ruby scripts/find_artist_music_links.rb \
  --name "Duo Ruut" \
  --name "Bille" \
  --name "Duga"
```

Standardmäßig entstehen diese Dateien:

- `.codex-tmp/artist-music-links/artist_music_links.csv`
- `.codex-tmp/artist-music-links/artist_music_links.json`

Die JSON-Datei enthält zusätzlich bis zu zehn bewertete Alternativen pro
Festival-Act. API-Antworten werden unter `.codex-tmp/artist-music-links/cache`
zwischengespeichert. Ein wiederholter Lauf ist dadurch deutlich schneller.

Die voreingestellten Pausen von 1,1 Sekunden für MusicBrainz und 3,1 Sekunden
für Apple respektieren die öffentlichen Rate-Limits. Ein vollständiger erster
Lauf kann deshalb mehrere Minuten dauern.

## Einstufungen

| Score | Status | Bedeutung |
| ---: | --- | --- |
| 90–100 | `verified` | durch starke oder mehrere unabhängige Merkmale bestätigt |
| 65–89 | `likely` | inhaltlich plausibler Treffer |
| 40–64 | `review` | Kandidat vorhanden, aber manuelle Prüfung erforderlich |
| 0–39 | `weak` | zu schwach für eine Empfehlung |
| – | `not_found` | kein Kandidat gefunden |

`suggested_url` wird standardmäßig nur ab 65 Punkten gesetzt. Der beste
schwächere Kandidat bleibt in `best_candidate_url` sichtbar. Die Schwelle lässt
sich mit `--minimum-score` ändern.

## Score-Kriterien

Positive Signale:

- +60: Apple-Link steht auf der offiziellen Festival-Website
- +40: Apple-Link ist bei MusicBrainz hinterlegt
- +30: Apple-Künstlername stimmt exakt
- +20: offizielle Website oder Social-ID stimmt mit MusicBrainz überein
- +10: MusicBrainz-Name stimmt exakt
- +10: MusicBrainz-Land stimmt
- +10: Treffer der Apple-Suche
- +15/+10/+5: Position 1, Top 3 oder Top 10 der Apple-Künstlersuche
- +35: Albumtitel aus der Festivalbeschreibung wurde gefunden
- +35: mehrere bei Apple genannte Musiker stehen in der Beschreibung
- +25: ein Apple-Katalogtitel steht auf der offiziellen Website
- +20: markanter Katalogbegriff steht in der Beschreibung
- +6: Genre passt zur Festivalbeschreibung

Widersprüche wie ein klar abweichender Künstlername oder ein anderes
MusicBrainz-Land ziehen Punkte ab. Der Endwert wird auf 0 bis 100 begrenzt.
Ein Album, dessen Titel lediglich dem Festivalnamen entspricht, gilt nicht als
Beleg. Dafür muss die Beschreibung es ausdrücklich als Album, EP, Single oder
Programm nennen oder mehrere beteiligte Musiker bestätigen.

## Grenzen

- Websites, die Links ausschließlich per JavaScript laden, können beim einfachen
  HTML-Abruf leer erscheinen.
- MusicBrainz ist gemeinschaftlich gepflegt und besonders bei neuen Acts
  unvollständig.
- Exakt gleichnamige Apple-Künstler bleiben ohne zusätzliche Kataloghinweise auf
  `review`.
- Beschreibungsmerkmale werden mit festen Regeln ausgewertet. Ausdrücklich
  benannte Album- oder Programmtitel und beteiligte Personen funktionieren gut;
  freie semantische Interpretationen finden nicht statt.
- Ein Albumlink kann das beste Ergebnis sein, wenn Apple kein gemeinsames
  Künstlerprofil für ein Projekt führt, etwa bei Bille oder Bentu.
