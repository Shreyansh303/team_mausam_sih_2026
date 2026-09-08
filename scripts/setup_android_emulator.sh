#!/usr/bin/env bash
# Create the `mausam_pixel` Android emulator (AVD) for the Mausam prototype - macOS / Linux.
#
#   ./scripts/setup_android_emulator.sh
#   ANDROID_HOME=~/development/android ./scripts/setup_android_emulator.sh
#
# The emulator is OPTIONAL: Chrome (`flutter run -d chrome`) and a real phone over USB both work
# without it, and judges are given the APK. Use this only if you want a virtual device.
#
# What it does:
#   1. locates the Android SDK (ANDROID_HOME / ANDROID_SDK_ROOT, then ~/development/android),
#   2. installs `platform-tools`, `emulator` and the system image with sdkmanager,
#   3. accepts the SDK licences,
#   4. creates the AVD `mausam_pixel` (skipped when it already exists).
#
# ARCHITECTURE: the image must match the CPU - `arm64-v8a` on Apple Silicon, `x86_64` on
# Intel/AMD. The default below is chosen from `uname -m`; override with IMAGE=... .
#
# DISK: the system image is ~1.5 GB and the emulator package another ~1 GB. Check free space
# (`df -h`) before running - the machine this was written on had ~5 GB spare.
#
# ACCELERATION: macOS uses the Hypervisor framework and needs no extra step. On Linux you need
# KVM once: `sudo apt install qemu-kvm && sudo usermod -aG kvm "$USER"` (log out and back in),
# plus virtualization (Intel VT-x / AMD-V) enabled in the BIOS/UEFI. The Windows equivalent -
# Windows Hypervisor Platform, an administrator step - is in scripts/setup_android_emulator.ps1.

set -euo pipefail

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/development/android}}"
AVD_NAME="${AVD_NAME:-mausam_pixel}"
DEVICE="${DEVICE:-pixel_6}"

case "$(uname -m)" in
  arm64 | aarch64) DEFAULT_ABI="arm64-v8a" ;;
  *) DEFAULT_ABI="x86_64" ;;
esac
IMAGE="${IMAGE:-system-images;android-35;google_apis;${DEFAULT_ABI}}"

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
note() { printf '    %s\n' "$1"; }

step "Android SDK root: $SDK_ROOT"
[ -d "$SDK_ROOT" ] || { echo "No Android SDK at '$SDK_ROOT'. Set ANDROID_HOME." >&2; exit 1; }

SDKMANAGER="$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="$SDK_ROOT/cmdline-tools/latest/bin/avdmanager"
for tool in "$SDKMANAGER" "$AVDMANAGER"; do
  [ -x "$tool" ] || { echo "Missing $tool - install the Android command-line tools." >&2; exit 1; }
done

if [ -z "${JAVA_HOME:-}" ]; then
  if [ -d "$HOME/development/jdk-17" ]; then
    export JAVA_HOME="$HOME/development/jdk-17"
    note "JAVA_HOME was not set; using $JAVA_HOME"
  else
    echo "JAVA_HOME is not set and no ~/development/jdk-17 was found. Point it at a JDK 17." >&2
    exit 1
  fi
fi

step "Installing platform-tools, emulator and $IMAGE"
note 'First run downloads ~2 GB; this can take several minutes.'
yes | "$SDKMANAGER" --sdk_root="$SDK_ROOT" 'platform-tools' 'emulator' "$IMAGE"

step 'Accepting SDK licences'
yes | "$SDKMANAGER" --sdk_root="$SDK_ROOT" --licenses > /dev/null

if "$AVDMANAGER" list avd -c | grep -qx "$AVD_NAME"; then
  step "AVD '$AVD_NAME' already exists - leaving it alone"
else
  step "Creating AVD '$AVD_NAME' from $IMAGE"
  echo no | "$AVDMANAGER" create avd -n "$AVD_NAME" -k "$IMAGE" -d "$DEVICE"
fi

step 'Done'
note "Start it with:  ./scripts/run_emulator.sh"
note "Then:           cd app && flutter run -d $AVD_NAME"
note 'Backend URL inside the emulator is http://10.0.2.2:8000 (not localhost).'
