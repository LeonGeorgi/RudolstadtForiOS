"""Build unaligned, full-resolution Sketch/native comparison artifacts."""
from pathlib import Path
import hashlib
import html
import json
from PIL import Image, ImageChops, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parent
STATES = {
    'full': ('FBF8D204-738D-48AA-8CA6-33EF5D260667', '57855BDB-8CCD-443E-8408-B103FFFE6C71', 'Freunde'),
    'plus': ('292CD7D0-CC68-43F8-93E2-DEA77CF1197E', '855D2C71-6AB3-4CEE-927A-FD38E2E82509', 'Einladungsmenü'),
    'avatar': ('4CCEA451-EF70-4E9E-8730-049475B432BE', '3F8FB529-040F-472B-AE8B-C1293FCC3E6B', 'Profilmenü'),
    'qr': ('87FC2A46-9F70-43BE-996F-0AA52D7DA8C1', '2B0D3982-8F55-4543-A30D-6ECABF8ED10D', 'Einladung'),
    'profile': ('BD5D7BE3-D936-4F63-8990-83F89104DA82', 'FFFBBB37-1075-4128-A668-AFF1F6DC9E6E', 'Mein Profil'),
    'color': ('E0FA3CF1-4834-4883-9777-BCD9825CE073', '18E43C9A-4927-4DDA-B208-D35DEB500A2F', 'Badge-Farbe'),
    'detail': ('66F331EE-D94E-4194-8EB5-8230DA7FE722', 'D4BF5770-768D-43C5-8827-3082FB018A43', 'Freundesdetail'),
    'recommendations': ('09377021-939A-4A12-BBC1-F6FF7187C07C', '4F309228-4274-4AF5-8EA4-5C6D93E0447B', 'Freundesempfehlungen'),
}

def relative(path):
    return str(path.relative_to(ROOT))

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

rows = []
sections = []
for index, platform in enumerate(['ios', 'android']):
    for state, (ios_id, android_id, title) in STATES.items():
        frame = (ios_id, android_id)[index]
        ref_path = ROOT / 'sketch-before' / (frame + '.png')
        ref = Image.open(ref_path).convert('RGB')
        expected = (1206, 2622 if platform == 'ios' else 2745)
        assert ref.size == expected
        artifacts = {}
        for phase in ['before', 'after']:
            native_path = ROOT / (platform + '-' + phase) / (state + '.png')
            native = Image.open(native_path).convert('RGB')
            assert native.size == ref.size, (platform, state, native.size, ref.size)
            a, b = ImageOps.grayscale(ref), ImageOps.grayscale(native)
            positive, negative = ImageChops.subtract(b, a), ImageChops.subtract(a, b)
            channel = Image.merge('RGB', (positive, negative, positive))
            rgb = ImageChops.difference(ref, native)
            # Only the upper system bar is masked. No alignment, crop, scaling or blur.
            top = 186 if platform == 'ios' else 132
            for picture in [channel, rgb]:
                ImageDraw.Draw(picture).rectangle((0, 0, picture.width - 1, top - 1), fill='black')
            folder = ROOT / ('comparison-' + phase)
            folder.mkdir(exist_ok=True)
            channels = folder / f'{platform}-{state}-channels.png'
            colors = folder / f'{platform}-{state}-rgb.png'
            channel.save(channels)
            rgb.save(colors)
            artifacts[phase] = dict(native=relative(native_path), sha256=digest(native_path),
                                    channels=relative(channels), rgb=relative(colors))
        rows.append(dict(platform=platform, state=state, frameID=frame,
                         reference=relative(ref_path), referenceSHA256=digest(ref_path),
                         size=list(ref.size), artifacts=artifacts))
        figures = [('Sketch', relative(ref_path)), ('Vorher', artifacts['before']['native']),
                   ('Nachher', artifacts['after']['native']),
                   ('Kanäle nachher', artifacts['after']['channels']),
                   ('RGB nachher', artifacts['after']['rgb'])]
        sections.append(f'<section id="{platform}-{state}"><h2>{platform.upper()} · {html.escape(title)}</h2>'
                        '<div class="pair">' + ''.join(
                            f'<figure><figcaption>{caption}</figcaption><a href="{path}"><img loading="lazy" src="{path}" width="402"></a></figure>'
                            for caption, path in figures) + '</div></section>')

report = dict(date='2026-11-05', locale='de-DE', appearance='light', scale=3,
              sketchDocument='../Rudolstadt.sketch', sketchEdited=False,
              devices=dict(ios='iPhone 17 Pro · iOS 27.0 · 402×874 pt',
                           android='Android 36 · Google APIs ARM64 · 402×915 dp · 480 dpi'),
              data=dict(project='festival-friends-dev', account='Test · Anna', friendCount=3,
                        source='Vorbereitete Entwicklungskonten; regulärer App-Betrieb, kein Screenshot-Modus',
                        reference='Illustrative Profile und API-Künstler aus den Sketch-Entwürfen',
                        credentials='Privat über Test-Runner bereitgestellt; keine Zugangsschlüssel in diesen Artefakten'),
              method=dict(alignment=False, crop=False, scale=False, blur=False,
                          maskTopPixels=dict(ios=186, android=132),
                          formula='d=Gray(native)-Gray(Sketch); RGB=(max(d,0),max(-d,0),max(d,0))',
                          material='Liquid-Glass-Material aus der Bewertung ausgenommen; Text und Symbole bleiben sichtbar'),
              corrections=dict(ios=['Einzüge der Empfehlungsgalerie und Überschrift',
                                    'Getrennte native Toolbar-Aktionen mit 42-pt-Profilavatar',
                                    'Ausführliche Profilzähler und Zeilenabstände',
                                    'Profilformular mit Abständen aus Sketch',
                                    'Farbauswahl ohne zusätzliche Listenkarten, mit sichtbarer Beschriftung',
                                    'Kompakter QR-Code und beide nativen sekundären Schaltflächen',
                                    'Kompakter Detailkopf, transparenter Hintergrund und Festivalbezeichnung'],
                               android=['264-dp-Empfehlungskarten mit passender Typografie',
                                        '258-dp-Menüs an der rechten Toolbar-Kante',
                                        'Profilformular und Farbauswahl mit korrigierter vertikaler Anordnung',
                                        '304×280-dp-QR-Karte und Buttonabstände',
                                        '140-dp-Empfehlungszeilen mit 20-sp-Titel und 12-sp-Aktivitäten',
                                        'Hochauflösende Künstlerbilder auch in Empfehlungszeilen']),
              limitations=['Andere echte Namen, Profilfarben, Zähler, Bilder und Empfehlungen verhindern vollständige Pixelgleichheit.',
                           'Die iOS-Nachrichtenleiste ist im Live-Betrieb auch auf Unterseiten sichtbar und wechselt ihren Inhalt.',
                           'Android hat eine native Zurück-Aktion auf der Freunde-Unterseite; die große Sketch-App-Bar zeigt diese nicht.',
                           'Android-App-Bar beginnt im Emulator bei 118 px statt 132 px in Sketch (14 px / 4⅔ dp Unterschied der Systemleiste); Quellbilder bleiben unverändert.',
                           'iOS-Empfehlungen behalten ihren vorhandenen Filterbutton; die Sketch-Hauptansicht zeigt diesen Unterseiten-Button nicht.',
                           'Einrichtung, Leerzustand, Annahme, ungültige Einladung, Freundesprofil ohne Einträge, Kamera und Zugriffsverweigerung sind in diesem Vergleich nicht aufgenommen.',
                           'Dunkelmodus, große Schrift und Englisch sind nicht Teil dieser Aufnahmeserie.'],
              tests=dict(
                  android=dict(result='passed', test='FriendsLayoutTests.captureConnectedFriendLayouts', log='/tmp/friends-visual-android-final3.log', states=8),
                  ios=dict(result='passed', test='FriendsLayoutTests.testConnectedFriendLayouts', log='/tmp/friends-visual-ios-final2.log', states=8, homeRecheck=dict(result='passed', test='FriendsLayoutTests.testHomeFriendLayouts', log='/tmp/friends-visual-ios-home-final2.log', states=3)),
                  compilation='Native Screenshots build-for-testing and Android app/test APK builds passed',
                  qrInvitations='Captured invitations replaced after recording; no longer valid'),
              captures=rows)
(ROOT / 'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
intro = '''<!doctype html><html lang="de"><meta charset="utf-8"><title>Freunde · Sketch / Simulator</title>
<style>body{font:16px system-ui;margin:24px;background:#eee;color:#171717}p{max-width:1000px;line-height:1.5}.pair{display:flex;gap:20px;overflow:auto}figure{margin:0;flex:none}img{display:block;width:402px;height:auto}figcaption{margin:8px 0}section{margin:36px 0}nav{display:flex;gap:16px;flex-wrap:wrap}a{color:#782c74}</style>
<h1>Freunde · Sketch / Simulator · 5. November 2026</h1>
<p>Acht Zustände je Plattform, Deutsch und helle Darstellung. Reguläre Entwicklungskonten mit echten Programmdaten. Die Entwürfe enthalten andere Beispielprofile und Künstler. Deshalb bewerten die Differenzbilder Geometrie und Komponenten; sie belegen keine vollständige Pixelgleichheit.</p>
<p>Quellen unverändert bei 3×. Keine Ausrichtung, Verschiebung, Skalierung oder Unschärfe. Nur die obere Systemleiste ist maskiert. Magenta: Sketch dunkler; Grün: Simulator dunkler. Materialeffekte von Liquid Glass werden getrennt von Schrift und Symbolen beurteilt.</p>
<p><a href="verification.json">Prüfumfang, Korrekturen und verbleibende Unterschiede</a></p><nav>'''
nav = ''.join(f'<a href="#{p}-{s}">{p.upper()} · {html.escape(t[2])}</a>' for p in ['ios','android'] for s,t in STATES.items())
(ROOT / 'index.html').write_text(intro + nav + '</nav>' + ''.join(sections) + '</html>\n')
print(f'Generated {len(rows)} comparisons, with before/after signed and RGB differences.')
