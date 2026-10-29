# Android-Künstlerliste

Die native Android-App verwendet Jetpack Compose und das bestehende KMP-Modul
`shared`. Sie zeigt ausschließlich die alphabetische Künstlerliste mit Ländern
aus dem mitgelieferten Rudolstadt-Programm 2026. Die Herkunft der Daten steht
sichtbar über der Liste. Es gibt noch keinen Online-Abruf, keine Detailansicht,
persönlichen Daten oder Synchronisierung. Die gemeinsamen Ressourcen werden aus
dem Bibliothekspaket gelesen, nicht für Android kopiert.

## Auf diesem Mac starten

Android Studio ist nicht erforderlich. Benötigt werden JDK 17 und das Android-SDK
unter `~/Library/Android/sdk`. Der eingerichtete ARM64-Emulator heißt
`Rudolstadt_API_36` und verwendet Android 16 / API 36 mit Google APIs.

Im Projektstamm:

```sh
./scripts/android/run-emulator.sh
```

Das Skript baut die Debug-App, startet beziehungsweise verwendet diesen Emulator,
installiert die APK und öffnet die Künstlerliste. Es beendet keine anderen
Emulatoren. Logs liegen unter `artifacts/android/`. Für einen anderen SDK-Pfad
`ANDROID_HOME` setzen; AVD und Port lassen sich mit `ANDROID_AVD_NAME` und
`ANDROID_EMULATOR_PORT` überschreiben.

## SDK und virtuelles Gerät auf einem weiteren Mac einrichten

Die offiziellen [Android-Kommandozeilenwerkzeuge](https://developer.android.com/studio#command-line-tools-only)
unter `$ANDROID_HOME/cmdline-tools/latest` installieren. Danach:

```sh
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export ANDROID_HOME="$HOME/Library/Android/sdk"
android_cli="$ANDROID_HOME/cmdline-tools/latest/bin/android"
"$android_cli" --sdk="$ANDROID_HOME" sdk install platforms/android-36
"$android_cli" --sdk="$ANDROID_HOME" sdk install build-tools/35.0.0
"$android_cli" --sdk="$ANDROID_HOME" sdk install platform-tools
"$android_cli" --sdk="$ANDROID_HOME" sdk install emulator
"$android_cli" --sdk="$ANDROID_HOME" sdk install system-images/android-36/google_apis/arm64-v8a
echo no | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd \
  --name Rudolstadt_API_36 --package 'system-images;android-36;google_apis;arm64-v8a' \
  --device pixel_7a
```

Das ARM64-Systemabbild ist für Apple Silicon. Auf Intel-Macs ein passendes
x86_64-Abbild wählen. Der Emulator kann regulär über sein Fenster beendet werden.

## Bauen und prüfen

```sh
export ANDROID_HOME="$HOME/Library/Android/sdk"
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
./gradlew :androidApp:assembleDebug :androidApp:testDebugUnitTest :androidApp:lintDebug
./gradlew checkKotlinFormat :shared:verifyAndroidResources
```

Der Android-Modultest lädt die echten Ressourcen aus `shared` und prüft die
Künstlerliste. Die APK liegt unter
`androidApp/build/outputs/apk/debug/androidApp-debug.apk`.
