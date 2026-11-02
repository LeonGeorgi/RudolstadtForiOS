# Signierte Android-APK ohne Play Store

Im Repository-Stamm ausführen (JDK 17 und Android SDK erforderlich):

```sh
scripts/android/build-release.sh
```

Das Skript baut die Release-Variante, richtet das APK-ZIP auf 16-KiB-Grenzen
aus, signiert mit `apksigner` und prüft Signatur sowie Ausrichtung.
Die installierbare Ausgabe liegt in `artifacts/android/rudolstadt-release.apk`.
Für einen Build mit bereits lokal verfügbaren Abhängigkeiten kann `--offline`
angehängt werden. Android Build Tools 35.0.0 werden standardmäßig verwendet;
`ANDROID_BUILD_TOOLS_VERSION` erlaubt eine andere installierte Version.

## Lokal eingerichtete Signatur

- Keystore: `~/.android/keystores/rudolstadt-release.p12` (PKCS12, RSA 3072).
- Alias: `rudolstadt-release`.
- Passwort: macOS-Anmeldeschlüsselbund, Dienst
  `de.leongeorgi.rudolstadt.android.release`, Account `rudolstadt-release`.
- Öffentlicher Zertifikatsfingerabdruck: `website/.well-known/assetlinks.json`.

Der private Schlüssel und sein Passwort gehören nicht ins Repository.
**Keystore und Passwort unabhängig vom Mac sicher sichern**, bevor die APK
weitergegeben wird. Künftige Updates der APK benötigen denselben Schlüssel.
Das Build-Skript erzeugt und ersetzt keine Schlüssel.

Auf einem anderen Rechner können `RUDOLSTADT_KEYSTORE`,
`RUDOLSTADT_KEY_ALIAS` und `RUDOLSTADT_SIGNING_PASSWORD` über eine geschützte
Umgebung bereitgestellt werden. Ohne Passwortvariable liest das Skript aus dem
macOS-Schlüsselbund. Passwörter nicht als Kommandozeilenargument eingeben;
das Skript nicht mit Shell-Tracing (`bash -x`) aufrufen.

## Installation und Linktest

Eine vorhandene Debug-APK hat einen anderen Signaturschlüssel. Für den Test
ein separates Gerät oder einen eigenen Emulator verwenden. Eine Deinstallation
der Debug-App würde deren lokale Daten entfernen.

```sh
adb install artifacts/android/rudolstadt-release.apk
adb shell pm verify-app-links --re-verify de.leongeorgi.rudolstadt.android
# Nach Abschluss der asynchronen Verifizierung:
adb shell pm get-app-links --user cur de.leongeorgi.rudolstadt.android
adb shell am start -W -a android.intent.action.VIEW \
  -c android.intent.category.BROWSABLE \
  -d https://festival.leongeorgi.de/rudolstadt/2026/artists/67
```

Die Domain muss als `verified` erscheinen. Der letzte Aufruf enthält absichtlich
keinen Paketnamen: Android soll die App anhand der veröffentlichten Zuordnung
auswählen. Zusätzlich denselben Link aus einer Nachricht auf einem echten
Android-Gerät antippen. Die Zuordnungsdatei allein installiert keine App.

Bei einer späteren Play-Veröffentlichung den App-Signaturschlüssel bewusst
wählen. Verwendet Google einen anderen Schlüssel, dessen SHA-256 zusätzlich
in `assetlinks.json` aufnehmen; der Upload-Schlüssel ist dafür nicht maßgeblich.
