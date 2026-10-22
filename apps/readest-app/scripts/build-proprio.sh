#!/usr/bin/env bash
# Compila o APK próprio (aarch64) assinado com ~/.android/readest-release.jks.
# Uso: scripts/build-proprio.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."

export JAVA_HOME="${JAVA_HOME:-$HOME/tools/jdk-21.0.12.1+1}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export NDK_HOME="${NDK_HOME:-$ANDROID_HOME/ndk/28.2.13676358}"
export PATH="$HOME/.local/bin:$JAVA_HOME/bin:$PATH"

# Como no CI (release.yml): gera o projeto Gradle completo e restaura os arquivos versionados
if [[ ! -x src-tauri/gen/android/gradlew ]]; then
  rm -rf src-tauri/gen/android
  pnpm tauri android init
  pnpm tauri icon ../../data/icons/readest-book.png
  git checkout -- src-tauri/gen src-tauri/icons
fi

cp "$HOME/.android/readest-release.properties" src-tauri/gen/android/keystore.properties

pnpm exec dotenv -e .env.proprio -e .env.tauri -- pnpm tauri android build -t aarch64 --apk

apk=src-tauri/gen/android/app/build/outputs/apk/universal/release/app-universal-release.apk
echo "APK: $(realpath "$apk")"

if [[ "${1:-}" == "--install" ]]; then
  ADB="${ADB:-/mnt/c/Users/mathe/AppData/Local/Microsoft/WinGet/Packages/Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe/scrcpy-win64-v4.1/adb.exe}"
  # adb.exe é do Windows: precisa de caminho Windows
  # ADB_SERIAL: escolhe o aparelho quando o adb lista mais de um (ex.: IP e mDNS)
  "$ADB" ${ADB_SERIAL:+-s "$ADB_SERIAL"} install -r "$(wslpath -w "$apk")"
fi
