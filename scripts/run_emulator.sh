#!/usr/bin/env bash
# Start the `mausam_pixel` Android emulator and wait until it has booted - macOS / Linux.
#
#   ./scripts/run_emulator.sh
#   COLD_BOOT=1 ./scripts/run_emulator.sh        # ignore the saved snapshot
#   AVD_NAME=other ./scripts/run_emulator.sh
#
# Run ./scripts/setup_android_emulator.sh once first. The emulator keeps running after this
# script returns; stop it by closing its window or with `adb emu kill`.

set -euo pipefail

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/development/android}}"
AVD_NAME="${AVD_NAME:-mausam_pixel}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"

EMULATOR="$SDK_ROOT/emulator/emulator"
ADB="$SDK_ROOT/platform-tools/adb"

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
note() { printf '    %s\n' "$1"; }

for tool in "$EMULATOR" "$ADB"; do
  [ -x "$tool" ] || { echo "Missing $tool - run ./scripts/setup_android_emulator.sh first." >&2; exit 1; }
done

if ! "$EMULATOR" -list-avds | grep -qx "$AVD_NAME"; then
  echo "No AVD called '$AVD_NAME'. Run ./scripts/setup_android_emulator.sh." >&2
  "$EMULATOR" -list-avds >&2
  exit 1
fi

args=(-avd "$AVD_NAME" -netdelay none -netspeed full)
[ -n "${COLD_BOOT:-}" ] && args+=(-no-snapshot-load)

step "Starting $AVD_NAME"
"$EMULATOR" "${args[@]}" > /dev/null 2>&1 &

step 'Waiting for the device (adb wait-for-device)'
"$ADB" start-server > /dev/null
"$ADB" wait-for-device

step 'Waiting for the boot to complete'
deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n')" = "1" ]; then
    serial=$("$ADB" devices | awk '/^emulator-/ {print $1; exit}')
    step "Booted: $serial"
    note "cd app && flutter run -d $serial"
    note 'In the app, set Settings -> Backend URL to http://10.0.2.2:8000'
    note '(10.0.2.2 is the emulator alias for the host machine; localhost is the emulator itself.)'
    exit 0
  fi
  sleep 3
done

echo "The emulator did not finish booting within ${TIMEOUT_SECONDS}s. Try COLD_BOOT=1, or check" >&2
echo "hardware acceleration (macOS: nothing to do; Linux: KVM + BIOS virtualization)." >&2
exit 1
