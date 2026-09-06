#!/usr/bin/env bash
# Put the Team Mausam Flutter toolchain on PATH for the CURRENT Git Bash / MSYS session.
#
#   source scripts/flutter_env.sh
#
# scripts/setup_flutter_windows.ps1 writes the user environment with setx, which only
# affects shells started afterwards; this file fixes up a shell that is already running.
#
# Override the toolchain root with MAUSAM_SDK_ROOT (Windows-style path), e.g.
#   MAUSAM_SDK_ROOT='E:\sdk' source scripts/flutter_env.sh

_mausam_sdk_root_win="${MAUSAM_SDK_ROOT:-D:\\sdk}"

# Windows-style path (what java/gradle/flutter want) -> POSIX path (what bash wants).
if command -v cygpath >/dev/null 2>&1; then
  _mausam_sdk_root_posix="$(cygpath -u "$_mausam_sdk_root_win")"
else
  _mausam_sdk_root_posix="$(printf '%s' "$_mausam_sdk_root_win" \
    | sed -e 's|\\|/|g' -e 's|^\([A-Za-z]\):|/\L\1|')"
fi

export FLUTTER_HOME="${_mausam_sdk_root_win}\\flutter"
export JAVA_HOME="${_mausam_sdk_root_win}\\jdk-17"
export ANDROID_HOME="${_mausam_sdk_root_win}\\android"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

# The Gradle wrapper downloads its distribution over java.net.HttpURLConnection, which has no
# IPv6->IPv4 fallback; a black-holed IPv6 route to services.gradle.org makes the first
# `flutter build apk` hang and then fail. Harmless where IPv6 works. docs/SETUP_WINDOWS.md §7.10.
case "${GRADLE_OPTS:-}" in
  *-Djava.net.preferIPv4Stack=true*) ;;
  '') export GRADLE_OPTS='-Djava.net.preferIPv4Stack=true' ;;
  *)  export GRADLE_OPTS="$GRADLE_OPTS -Djava.net.preferIPv4Stack=true" ;;
esac

_mausam_bins="
${_mausam_sdk_root_posix}/flutter/bin
${_mausam_sdk_root_posix}/jdk-17/bin
${_mausam_sdk_root_posix}/android/platform-tools
${_mausam_sdk_root_posix}/android/cmdline-tools/latest/bin
"

_mausam_missing=""
for _d in $_mausam_bins; do
  case ":$PATH:" in
    *":$_d:"*) ;;
    *) PATH="$_d:$PATH" ;;
  esac
  if [ ! -d "$_d" ]; then
    _mausam_missing="$_mausam_missing $_d"
  fi
done
export PATH

if [ -n "$_mausam_missing" ]; then
  echo "flutter_env: these directories do not exist yet:"
  for _d in $_mausam_missing; do echo "  $_d"; done
  echo "Run: powershell -ExecutionPolicy Bypass -File scripts/setup_flutter_windows.ps1"
else
  echo "flutter_env: FLUTTER_HOME=$FLUTTER_HOME  JAVA_HOME=$JAVA_HOME  ANDROID_HOME=$ANDROID_HOME"
fi

unset _mausam_sdk_root_win _mausam_sdk_root_posix _mausam_bins _mausam_missing _d
