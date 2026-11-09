#!/usr/bin/env python3
"""Create the offline, Debug-only Fantasy Festival fixture.

Run with --download to resolve free Commons photos and retain their attribution.
Use --download-descriptions to acquire Wikipedia biographies in German/English.
Without those flags, reuse the checked-in manifests (no network access).
Only the Apple Debug resource build phase copies this directory into the app.
"""

import argparse
import hashlib
import html
import json
import re
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parents[2]
DESTINATION = ROOT / "shared/src/debugResources/FantasyFestival"
USER_AGENT = "FantasyFestivalFixture/1.0 (github.com/LeonGeorgi/RudolstadtForiOS; offline debug fixture)"

# Wikipedia titles disambiguate the actual acts; country and genre are editorial
# test metadata. IDs are the stable one-based row numbers, never an API page ID.
ROSTER = """
Michael Jackson|USA|Pop
Madonna|USA|Pop
Prince (musician)|USA|Funk
Beyoncé|USA|Pop
Taylor Swift|USA|Pop
David Bowie|GBR|Rock
Queen (band)|GBR|Rock
ABBA|SWE|Pop
The Beatles|GBR|Rock
The Rolling Stones|GBR|Rock
Elton John|GBR|Pop
Stevie Wonder|USA|Soul
Whitney Houston|USA|Soul
Aretha Franklin|USA|Soul
Tina Turner|USA|Rock
Elvis Presley|USA|Rock
Johnny Cash|USA|Country
Dolly Parton|USA|Country
Bob Dylan|USA|Folk
Bruce Springsteen|USA|Rock
Billy Joel|USA|Pop
Paul McCartney|GBR|Rock
John Lennon|GBR|Rock
George Harrison|GBR|Rock
Ringo Starr|GBR|Rock
Fleetwood Mac|GBR|Rock
Eagles (band)|USA|Rock
Led Zeppelin|GBR|Rock
Pink Floyd|GBR|Rock
The Who|GBR|Rock
The Doors|USA|Rock
Jimi Hendrix|USA|Rock
Janis Joplin|USA|Rock
Eric Clapton|GBR|Blues
Santana (band)|USA|Rock
Metallica|USA|Metal
Iron Maiden|GBR|Metal
Black Sabbath|GBR|Metal
AC/DC|AUS|Rock
Guns N' Roses|USA|Rock
Nirvana (band)|USA|Rock
Foo Fighters|USA|Rock
Pearl Jam|USA|Rock
Red Hot Chili Peppers|USA|Rock
Green Day|USA|Punk
Linkin Park|USA|Rock
Radiohead|GBR|Rock
Oasis (band)|GBR|Rock
Blur (band)|GBR|Rock
Coldplay|GBR|Pop
U2|IRL|Rock
R.E.M.|USA|Rock
The Cure|GBR|Rock
Depeche Mode|GBR|Electronic
Pet Shop Boys|GBR|Electronic
Eurythmics|GBR|Pop
Annie Lennox|GBR|Soul
George Michael|GBR|Pop
Robbie Williams|GBR|Pop
Adele|GBR|Soul
Amy Winehouse|GBR|Soul
Ed Sheeran|GBR|Pop
Dua Lipa|GBR|Pop
Harry Styles|GBR|Pop
Elvis Costello|GBR|Rock
Sting (musician)|GBR|Rock
Peter Gabriel|GBR|Rock
Phil Collins|GBR|Pop
Genesis (band)|GBR|Rock
Dire Straits|GBR|Rock
Mark Knopfler|GBR|Rock
Bon Jovi|USA|Rock
Aerosmith|USA|Rock
Kiss (band)|USA|Rock
Alice Cooper|USA|Rock
Rammstein|DEU|Metal
Scorpions (band)|DEU|Rock
Kraftwerk|DEU|Electronic
Nena|DEU|Pop
Herbert Grönemeyer|DEU|Pop
Die Ärzte|DEU|Punk
Die Toten Hosen|DEU|Punk
Udo Lindenberg|DEU|Rock
Peter Maffay|DEU|Rock
Falco (musician)|AUT|Pop
Hubert von Goisern|AUT|Folk
Björk|ISL|Electronic
Sigur Rós|ISL|Rock
A-ha|NOR|Pop
Roxette|SWE|Pop
Europe (band)|SWE|Rock
Avicii|SWE|Electronic
Daft Punk|FRA|Electronic
David Guetta|FRA|Electronic
Jean-Michel Jarre|FRA|Electronic
Air (French band)|FRA|Electronic
The Chemical Brothers|GBR|Electronic
The Prodigy|GBR|Electronic
Fatboy Slim|GBR|Electronic
Moby|USA|Electronic
Tiësto|NLD|Electronic
Armin van Buuren|NLD|Electronic
Martin Garrix|NLD|Electronic
Calvin Harris|GBR|Electronic
Lady Gaga|USA|Pop
Rihanna|BRB|Pop
Britney Spears|USA|Pop
Christina Aguilera|USA|Pop
Katy Perry|USA|Pop
Billie Eilish|USA|Pop
Lana Del Rey|USA|Pop
Ariana Grande|USA|Pop
Miley Cyrus|USA|Pop
Pink (singer)|USA|Pop
Shakira|COL|Pop
Jennifer Lopez|USA|Pop
Celine Dion|CAN|Pop
Alanis Morissette|CAN|Rock
Avril Lavigne|CAN|Rock
Bryan Adams|CAN|Rock
Neil Young|CAN|Folk
Joni Mitchell|CAN|Folk
Leonard Cohen|CAN|Folk
The Weeknd|CAN|Pop
Drake (musician)|CAN|Hip-Hop
Eminem|USA|Hip-Hop
Kendrick Lamar|USA|Hip-Hop
Snoop Dogg|USA|Hip-Hop
Missy Elliott|USA|Hip-Hop
Lauryn Hill|USA|Soul
Alicia Keys|USA|Soul
Nina Simone|USA|Jazz
Ella Fitzgerald|USA|Jazz
Louis Armstrong|USA|Jazz
Miles Davis|USA|Jazz
John Coltrane|USA|Jazz
Herbie Hancock|USA|Jazz
Norah Jones|USA|Jazz
Ray Charles|USA|Soul
James Brown|USA|Funk
Marvin Gaye|USA|Soul
Otis Redding|USA|Soul
Bob Marley|JAM|Reggae
Jimmy Cliff|JAM|Reggae
Buena Vista Social Club|CUB|Latin
Cesária Évora|CPV|World
Miriam Makeba|ZAF|World
Fela Kuti|NGA|Afrobeat
Youssou N'Dour|SEN|World
Angélique Kidjo|BEN|World
""".strip()

DISPLAY_NAMES = {
    "Prince (musician)": "Prince", "Queen (band)": "Queen",
    "Eagles (band)": "Eagles", "Santana (band)": "Santana",
    "Nirvana (band)": "Nirvana", "Oasis (band)": "Oasis", "Blur (band)": "Blur",
    "Sting (musician)": "Sting", "Genesis (band)": "Genesis", "Kiss (band)": "KISS",
    "Scorpions (band)": "Scorpions", "Falco (musician)": "Falco",
    "Europe (band)": "Europe", "Air (French band)": "Air", "Pink (singer)": "P!nk",
    "Drake (musician)": "Drake",
}

PHOTO_OVERRIDES = {
    "Pink Floyd": "File:Pink floyd live 8 london.jpg",
    "Scorpions (band)": "File:Scorpions live 2010.jpg",
}


def request_query(host, **parameters):
    url = f"https://{host}/w/api.php?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "formatversion": 2, **parameters,
    })
    for attempt in range(5):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=60) as response:
                result = json.load(response)
            if "error" in result:
                raise ValueError(result["error"])
            return result["query"]
        except (OSError, ValueError):
            if attempt == 4:
                raise
            time.sleep(5 * (attempt + 1))


def request_json(host, **parameters):
    return request_query(host, **parameters)["pages"]


def description_record(page, language):
    text = re.sub(r"\[\d+(?:,\s*\d+)*\]", "", page.get("extract", "")).strip()
    if len(text) < 800:
        # Short introductions can be only one sentence. Include the beginning of
        # their main article as well, so these remain useful layout fixtures.
        full_page = request_json(f"{language}.wikipedia.org", prop="extracts|revisions",
                                 pageids=page["pageid"], explaintext=1,
                                 exchars=1200, exsectionformat="plain", rvprop="ids")[0]
        text = re.sub(r"\[\d+(?:,\s*\d+)*\]", "", full_page.get("extract", "")).strip()
        page = full_page
    if len(text) < 400:
        raise ValueError(f"Missing biography for {language}:{page['title']}")
    # Keep naturally different lengths and paragraph breaks rather than padding
    # short biographies or repeating text. Very long introductions are excerpted
    # at paragraph boundaries; full source and revision stay in the manifest.
    paragraphs = text.split("\n\n")
    selected = []
    for paragraph in paragraphs:
        if selected and len("\n\n".join(selected + [paragraph])) > 6500:
            break
        selected.append(paragraph)
    source = f"https://{language}.wikipedia.org/wiki/" + urllib.parse.quote(page["title"].replace(" ", "_"))
    revision_id = page["revisions"][0]["revid"]
    return {
        "language": language, "title": page["title"], "text": "\n\n".join(selected),
        "sourceURL": source,
        "revisionURL": f"https://{language}.wikipedia.org/w/index.php?oldid={revision_id}",
        "authorsURL": source + "?action=history", "revisionID": revision_id,
        "license": "CC BY-SA 4.0", "licenseURL": "https://creativecommons.org/licenses/by-sa/4.0/",
    }


def download_descriptions(roster, destination):
    path = destination / "biographies.json"
    biographies = json.loads(path.read_text()) if path.exists() else []
    completed = {item["id"] for item in biographies}
    for offset in range(0, len(roster), 15):
        batch = [act for act in roster[offset:offset + 15] if act["id"] not in completed]
        if not batch:
            continue
        query = request_query("en.wikipedia.org", prop="extracts|langlinks|revisions",
                              exintro=1, explaintext=1, exlimit=20,
                              lllang="de", lllimit=500, rvprop="ids", redirects=1,
                              titles="|".join(act["title"] for act in batch))
        redirects = {item["from"]: item["to"] for item in query.get("redirects", [])}
        normalized = {item["from"]: item["to"] for item in query.get("normalized", [])}
        english = {page["title"]: page for page in query["pages"]}
        matches = {}
        for act in batch:
            title = normalized.get(act["title"], act["title"])
            title = redirects.get(title, title)
            page = english[title]
            german_title = next(link["title"] for link in page["langlinks"] if link["lang"] == "de")
            matches[act["id"]] = (page, german_title)
        german_query = request_query("de.wikipedia.org", prop="extracts|revisions",
                                     exintro=1, explaintext=1, exlimit=20, rvprop="ids", redirects=1,
                                     titles="|".join(title for _, title in matches.values()))
        german_redirects = {item["from"]: item["to"] for item in german_query.get("redirects", [])}
        german = {page["title"]: page for page in german_query["pages"]}
        for act in batch:
            page, title = matches[act["id"]]
            item = {"id": act["id"], "artist": act["name"],
                    "en": description_record(page, "en"),
                    "de": description_record(german[german_redirects.get(title, title)], "de")}
            biographies.append(item)
            path.write_text(json.dumps(sorted(biographies, key=lambda b: b["id"]), ensure_ascii=False, indent=2) + "\n")
            print(f"Biographies {act['id']:03}: {act['name']} ({len(item['de']['text'])}/{len(item['en']['text'])} characters)", flush=True)
        time.sleep(2)
    return biographies


def plain(value):
    return html.unescape(re.sub(r"<[^>]+>", "", value or "")).strip()


def download_photos(roster, destination):
    manifest_path = destination / "photos.json"
    photos = json.loads(manifest_path.read_text()) if manifest_path.exists() else []
    completed = {photo["id"] for photo in photos}
    for offset in range(0, len(roster), 15):
        batch = [act for act in roster[offset:offset + 15] if act["id"] not in completed]
        if not batch:
            continue
        pages = request_json("en.wikipedia.org", prop="pageimages", piprop="name|original",
                             pilicense="free", redirects=1,
                             titles="|".join(act["title"] for act in batch))
        file_titles = ["File:" + page["pageimage"] for page in pages if "pageimage" in page]
        file_titles += [PHOTO_OVERRIDES[act["title"]] for act in batch if act["title"] in PHOTO_OVERRIDES]
        info_pages = request_json("commons.wikimedia.org", prop="imageinfo",
                                 iiprop="url|extmetadata|sha1|size", iiurlwidth=960,
                                 titles="|".join(file_titles))
        infos_by_title = {page["title"].replace("_", " "): page.get("imageinfo", []) for page in info_pages}
        for act in batch:
            page = next((page for page in pages if page["title"] == act["title"]), None)
            if page is None and len(batch) == 1:
                page = pages[0]
            override = PHOTO_OVERRIDES.get(act["title"])
            if override is None and (page is None or "pageimage" not in page):
                print(f"NEEDS PHOTO {act['id']}: {act['title']}", flush=True)
                continue
            file_title = override or "File:" + page["pageimage"]
            infos = infos_by_title.get(file_title.replace("_", " "), [])
            if not infos:
                print(f"NOT COMMONS {act['id']}: {file_title}", flush=True)
                continue
            info = infos[0]
            metadata = info["extmetadata"]
            license_name = plain(metadata.get("LicenseShortName", {}).get("value"))
            if not (license_name.startswith(("CC BY", "CC0", "Public domain", "PDM"))):
                print(f"REVIEW LICENSE {act['id']}: {license_name}", flush=True)
                continue
            if info["sha1"] in {photo["sourceSHA1"] for photo in photos}:
                raise ValueError(f"Duplicate photograph for {act['title']}")
            photo = {
                "id": act["id"], "artist": act["name"], "fileTitle": file_title,
                "sourceURL": info["descriptionurl"], "originalURL": info["url"],
                "downloadURL": info.get("thumburl", info["url"]),
                "author": plain(metadata.get("Artist", {}).get("value")),
                "credit": plain(metadata.get("Credit", {}).get("value")),
                "license": license_name,
                "licenseURL": metadata.get("LicenseUrl", {}).get("value", ""),
                "sourceSHA1": info["sha1"], "image": f"images/{act['id']:03}.jpg",
            }
            photos.append(photo)
            manifest_path.write_text(json.dumps(sorted(photos, key=lambda p: p["id"]), ensure_ascii=False, indent=2) + "\n")
            print(f"Resolved {act['id']:03}: {act['name']} ({license_name})", flush=True)
        time.sleep(2)
    return photos


def download_files(photos, destination):
    for folder in ("images", "thumbnails"):
        (destination / folder).mkdir(exist_ok=True)
    for photo in sorted(photos, key=lambda p: p["id"]):
        image_path = destination / photo["image"]
        thumbnail_path = destination / photo["image"].replace("images/", "thumbnails/")
        if image_path.exists() and thumbnail_path.exists():
            photo["imageSHA256"] = hashlib.sha256(image_path.read_bytes()).hexdigest()
            continue
        with tempfile.TemporaryDirectory(prefix="fantasy-photo-") as temporary:
            source_path = Path(temporary) / "source"
            for attempt in range(5):
                try:
                    request = urllib.request.Request(photo["downloadURL"], headers={"User-Agent": USER_AGENT})
                    with urllib.request.urlopen(request, timeout=90) as response:
                        source_path.write_bytes(response.read())
                    break
                except OSError:
                    if attempt == 4:
                        raise
                    time.sleep(5 * (attempt + 1))
            for size, output in ((960, image_path), (240, thumbnail_path)):
                subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "75",
                                "--resampleHeightWidthMax", str(size), str(source_path),
                                "--out", str(output)], check=True, capture_output=True)
        photo["imageSHA256"] = hashlib.sha256(image_path.read_bytes()).hexdigest()
        print(f"Downloaded {photo['id']:03}: {photo['artist']}", flush=True)
        time.sleep(0.4)
    (destination / "photos.json").write_text(json.dumps(photos, ensure_ascii=False, indent=2) + "\n")


def build_program(roster, photos, biographies):
    assert len(roster) == 150
    assert {photo["id"] for photo in photos} == {act["id"] for act in roster}
    assert len({photo["sourceSHA1"] for photo in photos}) == 150
    photo_by_id = {photo["id"]: photo for photo in photos}
    biography_by_id = {item["id"]: item for item in biographies}
    assert set(biography_by_id) == {act["id"] for act in roster}
    artists = []
    for act in roster:
        photo = photo_by_id[act["id"]]
        biography = biography_by_id[act["id"]]
        descriptions = {}
        for language in ("de", "en"):
            text = re.sub(r"\[\d+(?:,\s*\d+)*\]", "", biography[language]["text"])
            descriptions[language] = "\n\n".join(
                paragraph.strip() for paragraph in re.split(r"\n+", text) if paragraph.strip()
            )
        artists.append({
            "id": act["id"], "name": act["name"], "countryCode": act["countryCode"],
            "genre": act["genre"], "image": photo["image"],
            "thumbnail": photo["image"].replace("images/", "thumbnails/"),
            "sourceURL": "https://en.wikipedia.org/wiki/" + urllib.parse.quote(act["title"].replace(" ", "_")),
            "photoSourceURL": photo["sourceURL"],
            "photoCredit": f"{photo['author']} · {photo['license']}",
            "photoLicense": photo["license"], "photoLicenseURL": photo["licenseURL"],
            "descriptionDE": descriptions["de"],
            "descriptionEN": descriptions["en"],
            "descriptionSources": [{key: value for key, value in biography[language].items() if key != "text"}
                                   for language in ("de", "en")],
        })
    stage_names = [
        ("Legendenbühne", "Legends Stage"), ("Sternenarena", "Starlight Arena"),
        ("Glashaus", "Glasshouse"), ("Flussdeck", "Riverside Deck"),
        ("Waldlichtung", "Forest Clearing"), ("Mondzelt", "Moon Tent"),
        ("Klanggarten", "Sound Garden"), ("Alte Maschinenhalle", "Old Engine Hall"),
        ("Panoramabühne", "Panorama Stage"), ("Club Unendlich", "Infinity Club"),
        ("Akustikhof", "Acoustic Courtyard"),
        ("Pavillon für große Stimmen und leise Zwischentöne", "Pavilion of Great Voices and Quiet Interludes"),
    ]
    # Fictional places on a compact real-world coordinate grid, explicitly marked
    # approximate by the adapter. No real venue or route is asserted.
    stages = [{
        "id": i + 1, "nameDE": names[0], "nameEN": names[1], "areaID": i // 4 + 1,
        "latitude": 50.7180 + (i // 4) * 0.0018,
        "longitude": 11.3320 + (i % 4) * 0.0025,
    } for i, names in enumerate(stage_names)]
    start = datetime(2027, 7, 15, 12, tzinfo=ZoneInfo("Europe/Berlin"))
    events = []
    for day in range(4):
        # 11 complete rounds on 12 stages, omitting 7 late slots = 125/day.
        for slot in range(125):
            stage_index = slot % 12
            round_index = slot // 12
            index = day * 125 + slot
            artist_index = (index * 37) % 150
            date = start + timedelta(days=day, minutes=round_index * 75 + (stage_index % 3) * 10)
            duration = [45, 60, 75, 90][(day + slot) % 4]
            if slot == 120:
                duration = 120  # Finale after midnight, still the same festival day.
            if slot == 121:
                duration = 20  # A short set beside the longer performances.
            events.append({
                "id": index + 1, "artistID": roster[artist_index]["id"],
                "stageID": stage_index + 1, "start": date.isoformat(),
                "durationMinutes": duration, "tagID": artists[artist_index]["genre"],
            })
    return {
        "schemaVersion": 1, "festivalID": "fantasy", "year": 2027,
        "timeZone": "Europe/Berlin", "artists": artists, "stages": stages,
        "events": events,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--download-descriptions", action="store_true")
    args = parser.parse_args()
    roster = []
    for i, line in enumerate(ROSTER.splitlines()):
        title, country, genre = line.split("|")
        roster.append({"id": i + 1, "title": title, "name": DISPLAY_NAMES.get(title, title),
                       "countryCode": country, "genre": genre})
    assert len(roster) == 150, len(roster)
    DESTINATION.mkdir(parents=True, exist_ok=True)
    photos = download_photos(roster, DESTINATION) if args.download else json.loads((DESTINATION / "photos.json").read_text())
    if len(photos) != 150:
        raise SystemExit(f"Resolved {len(photos)}/150 photos; complete the missing Commons selections before building.")
    if args.download:
        download_files(photos, DESTINATION)
    biographies = download_descriptions(roster, DESTINATION) if args.download_descriptions else json.loads((DESTINATION / "biographies.json").read_text())
    program = build_program(roster, photos, biographies)
    (DESTINATION / "program.json").write_text(json.dumps(program, ensure_ascii=False, indent=2) + "\n")
    credits = ["# Fantasy Festival source credits", "", "Fictional Debug-only concert program. Photos depict the named real acts.", "", "## Photos", "",
               "Each photo was resized to JPEG for offline use; thumbnails are separate sizes of the same photo.", ""]
    for photo in sorted(photos, key=lambda p: p["id"]):
        credits += [f"- **{photo['artist']}**: {photo['author']}. [{photo['fileTitle']}]({photo['sourceURL']}). {photo['license']} ({photo['licenseURL']})."]
    credits += ["", "## Artist descriptions", "",
                "Wikipedia introductory excerpts, converted to plain text, with citation markers removed where present. Longer introductions may be excerpted at paragraph boundaries. Text is available under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Article histories identify the contributors. The license applies to the article excerpts, not the application code.", ""]
    for item in sorted(biographies, key=lambda b: b["id"]):
        for language in ("de", "en"):
            source = item[language]
            credits += [f"- **{item['artist']} ({language})**: Wikipedia contributors, [{source['title']}]({source['sourceURL']}), [revision {source['revisionID']}]({source['revisionURL']}), [authors/history]({source['authorsURL']}). {source['license']}."]
    (DESTINATION / "CREDITS.md").write_text("\n".join(credits) + "\n")
    print(f"Created {len(program['artists'])} acts, {len(program['stages'])} stages and {len(program['events'])} events.")


if __name__ == "__main__":
    main()
