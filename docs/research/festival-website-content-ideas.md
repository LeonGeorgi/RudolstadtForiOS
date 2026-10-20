# Kuratierte Festivalinformationen: Ideen aus der offiziellen Website

Recherche: 20. Oktober 2026. Zweck: Inspiration für die bestehende App, keine Umsetzungsspezifikation oder Aufgabenliste. Alle Webbelege stammen vom Veranstalter. Website-Befunde und eigene Produktideen sind getrennt.

## Einordnung und Aktualität

Die [Startseite](https://www.rudolstadt-festival.de/startseite.html) kündigt bereits den 1.–4. Juli 2027 mit Korea an. Die hier untersuchten Programmseiten beschreiben überwiegend 2026, teilweise mit älteren Textresten. Die Beispiele belegen vorhandene Inhaltsarten; sie sind kein verifiziertes Programm für 2027. Eine redaktionelle Sammlung müsste daher immer ein Festivaljahr, einen Prüfstand und die Originalquelle tragen.

## Abgleich mit der App

Codebefund, ohne App-Start oder visuelle Prüfung: [MoreView](../../Shared/Screens/More/MoreView.swift) bietet News, Über die App, P+R, Bus, Spenden, Einstellungen und Synchronisierung. [BusView](../../Shared/Screens/More/BusView.swift) bindet ein KomBus-Webwidget ein; [ParkAndRideView](../../Shared/Screens/More/ParkAndRideView.swift) hat zwei Parkorte samt Beschreibung. [DataModel](../../Shared/Data/DataModel.swift) unterscheidet Künstler nach Bühne, Tanz, Straße und Sonstige sowie Spielorte nach Tickettyp. Die Bühnenkarte kennt bereits Service-Orte. Zeitplan und Künstler entdecken das Programm, aber dedizierte Einführungen in Workshops, Programmformate, Familienangebote, Camping und Besucher-FAQ sind im untersuchten UI nicht vorhanden. Einige dieser Informationen können bereits in einzelnen Künstlerbeschreibungen oder News vorkommen; die Lücke ist vor allem ihre Auffindbarkeit als zusammenhängendes Angebot.

## 1. Mitmachen: Workshops mit praktischen Teilnahmeinfos

**Website:** Die [Workshopübersicht 2026](https://www.rudolstadt-festival.de/programm/workshop.html) bietet deutlich mehr als Namen und Tags: „How to folk?“ richtet sich ausdrücklich an Session-Einsteiger. Evelyn Fink-Mennels Johlen/Juzen braucht keine Vorkenntnisse. Ralf Gehler/Vivien Zeller nennen passende Tonarten für mitgebrachte Instrumente und heißen Perkussion willkommen. Für Ingeborg Freytags Body Music muss nichts mitgebracht werden. Sara Curruchichs Gespräch ist auf Englisch.

**Idee:** Eine Übersicht „Selbst mitmachen“ mit Terminen und kurzen Antworten auf „Für wen?“, „Was bringe ich mit?“ und „Welche Sprache?“. Singen, Instrumente und Bewegung könnten die Auswahl erleichtern. Die konkrete Teilnahmeinfo wäre der Mehrwert gegenüber einem Workshopfilter.

**Grenze:** Jährliche redaktionelle Ergänzung nötig; Voraussetzungen lassen sich nicht zuverlässig aus Event-Tags ableiten. Website-Termine wurden nicht mit API und App synchron geprüft. Fehlende Angaben bedeuten unbekannt, nicht automatisch voraussetzungslos oder anmeldefrei.

## 2. Länderschwerpunkt als Einstieg ins Entdecken

**Website:** Die [Österreich-Seite 2026](https://www.rudolstadt-festival.de/programm/laenderschwerpunkt.html) verbindet eine Einführung in verschiedene Musiktraditionen und ihre Weiterentwicklung mit einer kuratierten Künstlerauswahl. [Skizzen aus Österreich](https://www.rudolstadt-festival.de/artist/sketches-of-austria.html) ergänzt das um ein Symposium mit der Hochschule für Musik Franz Liszt Weimar, acht Vorträgen und einer Diskussion an zwei Vormittagen.

**Idee:** „Dieses Jahr im Fokus“: ein kurzer eigener Einführungstext plus die zugehörigen Konzerte, Gespräche und Mitmachangebote. Besucher könnten von einem musikalischen Begriff direkt zu passenden Acts und Terminen gelangen. Das ergänzt die vorhandene Weltkarte um inhaltlichen Zusammenhang.

**Grenze:** Österreich gehört zu 2026, Korea ist erst für 2027 angekündigt. Die verlinkte Symposium-Detailübersicht leitet inzwischen zur Startseite um; ein vollständiges Vortragsschema ist damit nicht belegt.

## 3. Ein kleiner Führer durch die besonderen Programmformate

**Website:** [EBU](https://www.rudolstadt-festival.de/programm/ebu.html) erklärt das Euroradio Folk Festival als Festival im Festival: Rundfunkanstalten bringen eine Musikauswahl mit, zeichnen Konzerte auf und tauschen Aufnahmen aus. Die [RUTH-Seite 2026](https://www.rudolstadt-festival.de/programm/ruth.html) erklärt die Ehrung Dota Kehrs für ihr Mascha-Kaléko-Programm und verknüpft sie mit Preisverleihung und Konzert. Die [Profolk-Session](https://www.rudolstadt-festival.de/artist/profolk-session.html) lädt im Schillergarten ausdrücklich zum gemeinsamen Singen, Musizieren und Tanzen ein.

**Idee:** Wenige kurze „Was ist das?“-Texte direkt an passenden Veranstaltungen, ergänzt durch eine Übersicht „Das macht Rudolstadt besonders“. EBU, RUTH und offene Session bekommen damit eine verständliche Bedeutung statt nur eines Labels. Ein Session-Einstieg könnte anschließend zu „How to folk?“ führen.

**Grenze:** Keine große Festival-Enzyklopädie nötig. Aus einem Tanz-Tag folgt nicht automatisch Mitmachtanz. Die Tanz- und Festival-Plus-Übersichten leiten derzeit teilweise zur Startseite um; deren Details müssten vor einer Übernahme erneut geprüft werden.

## 4. Mit Kindern unterwegs

**Website:** Der Eintrag [Kinderfest](https://www.rudolstadt-festival.de/artist/kinderfest.html) hat ein eigenes erzählerisches Motto und Termine am Samstag und Sonntag im Programm 2026. Die [Preisseite](https://www.rudolstadt-festival.de/allgemeines/preise.html) nennt freien Eintritt unter sieben Jahren sowie Ermäßigungen für Sieben- bis Sechzehnjährige.

**Idee:** Ein Einstieg „Mit Kindern“ mit Kinderfest, geeigneten ausdrücklich gekennzeichneten Mitmachangeboten, Ort und einem kurzen praktischen Hinweis zur Ticketregel. Zusammengehörige Informationen wären sofort auffindbar, statt zwischen Künstlerliste und Serviceinformationen verteilt zu sein.

**Grenze:** Altersgruppen oder Eignung anderer Konzerte nicht erfinden. Der Kinderfest-Eintrag liefert nur einen gekürzten Text; sein weiterführender Link ist derzeit eine Startseiten-Weiterleitung. Familienservice wie Wickeln, Ruhezonen oder Betreuung ist in dieser Recherche nicht belegt.

## 5. „Wo komme ich mit meinem Ticket rein?“

**Website:** [Preise](https://www.rudolstadt-festival.de/allgemeines/preise.html) und [FAQ](https://www.rudolstadt-festival.de/service/faq.html) unterscheiden Festivalticket und vor Ort erhältliche Innenstadtkarten. Letztere gelten für Outdoor-Veranstaltungen im Innenstadtbereich; Indoor-Angebote benötigen das Festivalticket. Die FAQ erläutert außerdem den Bändchenerhalt für die Begleitperson eines Gastes mit Merkzeichen B.

**Idee:** Eine kurze verständliche Ticket- und Bändchenerklärung, aus der vorhandenen Ticketlegende der Bühnenkarte erreichbar. Besonders nützlich für Tagesbesucher: zu einer Bühne erfahren, welche Karte dort nötig ist und wo der Unterschied zwischen Innenstadt und gesamtem Festival liegt.

**Grenze:** Die App kennt Tickettypen bereits; daher lieber Erklärung und Verknüpfung ergänzen als eine zweite Kartenlogik bauen. Preise und Berechtigungen jährlich prüfen. Die FAQ ist kein Beleg für die bauliche Zugänglichkeit einzelner Spielorte.

## 6. „Mein Campingplatz“ statt einer langen allgemeinen Infoseite

**Website:** [Übernachtung](https://www.rudolstadt-festival.de/allgemeines/uebernachtung.html) und [Camperinfo](https://www.rudolstadt-festival.de/service/camperinfo.html) unterscheiden Z1–Z3 und C1–C3, Ausstattung, Anfahrt, Personen- und Fahrzeugtickets. Beispielsweise stehen auf Z1 Fahrzeuge und Zelte getrennt, ohne Stromanschluss; Z2 liegt im Freibad, dessen Regeln für Hunde und Glas zu beachten sind. Die Gemeinschaftsunterkunft erfordert eigenes Schlafzeug.

**Idee:** Den gebuchten Platz auswählen und eine kompakte, offline verfügbare Infoseite erhalten: Anfahrt, Ausstattung, wichtige Mitbringsel und Verbindung zum Shuttle. Kleine Vergleichstabelle für die Vorbereitung, danach nur der relevante Platz.

**Grenze:** Hoher konkreter Nutzen, aber jährlicher Pflegebedarf. Die Seiten enthalten unterschiedlich formulierte Fahrzeugregeln; für einen automatischen Eignungsberater reichen sie nicht zuverlässig. Platzwahl als Komfortfunktion wäre eine Idee, keine bereits vorhandene Buchungsintegration.

## 7. Ankommen und nachts zurückkommen

**Website:** [Shuttle Bus & Bahn](https://www.rudolstadt-festival.de/service/shuttle-bus.html) erklärt den in bestimmten Tarifzonen gültigen ÖPNV-Nutzen des Festivalbändchens, Sonderregeln für die Anreise vor dem Umtausch und die Nutzung von Innenstadttickets. Zusätzlich enthält die Seite Shuttlezeiträume und Abfahrtsorte, ausdrücklich für 2026.

**Idee:** Neben dem vorhandenen Buswidget ein kurzer Text „So nutzt du Bus und Bahn mit deinem Ticket“ sowie „Zurück zu meinem Campingplatz / nach Saalfeld“. Der Planer bleibt für konkrete Verbindungen zuständig; die App erklärt Voraussetzungen und erleichtert den richtigen Einstieg.

**Grenze:** Fahrplanzeiten nicht dauerhaft fest einbauen oder als Live-Abfahrten darstellen. Die auf der Seite genannte Anreiseregel umfasst einen konkreten Tag und Uhrzeit; sie muss für jedes Festival neu bestätigt werden.

## 8. Kurze Antworten auf typische Fragen vor Ort

**Website:** [Festivalregeln](https://www.rudolstadt-festival.de/service/festivalregeln.html) unterscheiden allgemeines Festivalgelände und abgesperrte Veranstaltungsbereiche. Sie nennen unter anderem Getränkeregeln, Hunde, Camping-Nachtruhe und offenes Feuer. [FAQ](https://www.rudolstadt-festival.de/service/faq.html) erklärt außerdem den Wegfall der Heidecksburg wegen Bauarbeiten und Ersatzspielorte.

**Idee:** Eine kleine nach Besuchersituationen sortierte Hilfe: „Was darf ich mitnehmen?“, „Mit Hund“, „Ankommen und Bändchen“, „Was ist dieses Jahr anders?“. Jeweils wenige klare Sätze mit Quelle, Stand und gegebenenfalls Sprung zur Karte. Das ergänzt News um dauerhaft auffindbare Antworten.

**Grenze:** Die Regelnseite hat einen unfertigen Heidecksburg-Zeitraum; die [Öffnungszeiten-Seite](https://www.rudolstadt-festival.de/allgemeines/oeffnungszeiten.html) enthält trotz 2026-Titel noch ein Gepäckdatum aus 2025. Die [Barrierefreiheitserklärung](https://www.rudolstadt-festival.de/footer/allgemeines/barrierefreiheit.html) handelt von der Website, nicht der Erreichbarkeit von Bühnen. Solche Inhalte brauchen redaktionelle Prüfung; aus fehlenden Angaben keine Besucherregeln oder Zugangszusagen ableiten.

## Eigene Priorisierung

1. **Mitmachen-Übersicht:** stärkster zusätzlicher Programmnutzwert; Voraussetzungen, Sprache und Mitbringsel beantworten echte Planungsfragen.
2. **Länderschwerpunkt und Formaterklärungen:** überschaubare redaktionelle Ergänzung, die der vorhandenen Künstler- und Terminwelt Zusammenhang gibt.
3. **Praktische Besucherhilfe:** Ticketzugang, Camping und Mobilität zusammenführen; bereits vorhandene Karte und Busansicht als Ausgangspunkt verwenden.
4. **Familieneinstieg:** klarer Nutzen für eine Zielgruppe, sobald vollständige jahresspezifische Informationen vorliegen.

Diese Reihenfolge ist eine Produktbewertung, keine Aussage des Veranstalters. Eine kleine, jährlich geprüfte Auswahl erscheint sinnvoller als die gesamte Website zu spiegeln. Als erster Umfang genügen ein Mitmachen-Einstieg und wenige kurze Einführungstexte mit Links zu den bestehenden App-Terminen.

## Prüfung

Offizielle Seiten wurden gelesen und Weiterleitungen beziehungsweise erkennbare Jahreskonflikte festgehalten. App-Abgleich basiert auf Quellcode; keine Builds, Tests oder App-Starts ausgeführt. Keine Laufzeit- oder visuelle Verifikation und kein vollständiger Abgleich zwischen Website, Live-API und gebündeltem Datenstand. Produktionscode und GitHub-Issues wurden nicht geändert.
