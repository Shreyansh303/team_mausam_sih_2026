# Setting up the Flutter toolchain on Windows (no admin rights)

Everything below installs **into your user account only**. Nothing writes to `C:\Program Files`,
nothing triggers a UAC prompt, and no installer/MSI is used — only zips extracted under `D:\sdk\`.

> Target of this document: a fresh Windows 10/11 machine that already has **Git for Windows**
> and **Google Chrome**. It does *not* need Android Studio, Visual Studio, or a JDK.

---

## 0. TL;DR

```powershell
git clone <repo> D:\Programming\team_mausam_sih_2026
cd D:\Programming\team_mausam_sih_2026
powershell -ExecutionPolicy Bypass -File scripts\setup_flutter_windows.ps1
```

Then **open a new terminal** and:

```powershell
cd D:\Programming\team_mausam_sih_2026\app
flutter pub get
flutter build web
flutter build apk --debug
```

---

## 1. What gets installed, and where

Versions verified on this machine (2026-09-07): **Flutter 3.47.2 stable** (Dart 3.13.2, engine
`a804b26164`), **Temurin JDK 17.0.20.1+1**, **Android SDK platform `android-36` + build-tools
`36.0.0`**, NDK `r28c` (pulled automatically by the first APK build).

| Path | Contents | Size |
|---|---|---|
| `D:\sdk\flutter` | Flutter SDK, stable channel 3.47.2 (includes Dart) | ~4.5 GB after first `flutter doctor` |
| `D:\sdk\jdk-17` | Eclipse Temurin JDK 17 (HotSpot), zip build | ~310 MB |
| `D:\sdk\android` | Android SDK — `platform-tools`, `platforms;android-3x`, `build-tools;3x.0.0` | ~1.5 GB |
| `D:\sdk\android\cmdline-tools\latest` | `sdkmanager`, `avdmanager`, `apkanalyzer` | ~150 MB |
| `D:\sdk\_downloads` | cached installer zips — **safe to delete** once setup succeeds | ~2.3 GB |
| `%USERPROFILE%\.gradle` | Gradle distributions + dependency cache (created by the first APK build) | ~1.5 GB |
| `%LOCALAPPDATA%\Pub\Cache` | Dart package cache | ~200 MB |

Budget **~10 GB** on `D:` and **~2 GB** on `C:` (Gradle + pub caches live in the user profile
and cannot be relocated without extra env vars — see §7.5 if `C:` is tight).

The script also writes these **user** environment variables (via `setx`; `PATH` via
`[Environment]::SetEnvironmentVariable` because `setx` truncates values at 1024 characters):

```
FLUTTER_HOME      = D:\sdk\flutter
JAVA_HOME         = D:\sdk\jdk-17
ANDROID_HOME      = D:\sdk\android
ANDROID_SDK_ROOT  = D:\sdk\android
PATH             += D:\sdk\flutter\bin
                    D:\sdk\jdk-17\bin
                    D:\sdk\android\platform-tools
                    D:\sdk\android\cmdline-tools\latest\bin
```

---

## 2. Prerequisites

1. **Git for Windows** on `PATH` — Flutter shells out to `git` constantly and refuses to run
   without it. Check with `git --version`. If missing, install the *user-space* Git installer
   ("Only for me" option, no admin needed) from <https://git-scm.com/download/win>.
2. **Google Chrome** — required for the `flutter build web` / `flutter run -d chrome` device.
   Already present on most machines; `flutter doctor` finds it via the registry.
3. **~10 GB free** on the drive holding `D:\sdk`.
4. **PowerShell 5.1** (ships with Windows). The script is written for it — no PowerShell 7 needed.

**Not required:** Android Studio, Visual Studio, IntelliJ, admin rights, `winget`, Developer Mode.

---

## 3. Run the setup script

```powershell
cd D:\Programming\team_mausam_sih_2026
powershell -ExecutionPolicy Bypass -File scripts\setup_flutter_windows.ps1
```

Useful switches:

```powershell
# install somewhere else
... -File scripts\setup_flutter_windows.ps1 -SdkRoot E:\sdk

# re-download and re-extract everything from scratch
... -File scripts\setup_flutter_windows.ps1 -Force

# skip the slow `flutter doctor -v` at the end
... -File scripts\setup_flutter_windows.ps1 -SkipDoctor
```

### Expected durations (100 Mbit/s connection, SSD)

| Step | Download | Time |
|---|---|---|
| Flutter stable zip | 1.9 GB | 4–12 min download + 2–4 min extract |
| Temurin JDK 17 zip | 190 MB | 20–60 s |
| Android cmdline-tools zip | 155 MB | 15–45 s |
| `sdkmanager` platform + build-tools | ~600 MB | 2–6 min |
| Licenses + `flutter config` + first `flutter doctor` | — | 2–5 min (Dart bootstrap runs here) |
| **Total (first run)** | **~2.9 GB** | **12–30 min** |
| Re-run (everything present) | 0 | ~1 min |

The script is **idempotent**: every step checks for its output first and prints `SKIP` if it is
already there. A failed run can simply be re-run — partially downloaded zips are written to
`*.part` and only renamed on success.

### After it finishes

`setx` does **not** change the environment of any terminal that is already open. Either:

* open a **new** terminal, or
* fix up the current one:

```powershell
. .\scripts\flutter_env.ps1        # PowerShell — note the leading "dot space"
```

```bash
source scripts/flutter_env.sh      # Git Bash
```

Verify:

```powershell
flutter --version
flutter doctor -v
```

---

## 4. What "good" looks like in `flutter doctor`

```
[!] Flutter (Channel stable, 3.47.2, ...)      <- only "binary is not on your path" warnings
[√] Windows Version (Windows 11 or higher, 25H2)
[√] Android toolchain - develop for Android devices (Android SDK version 36.0.0)
[√] Chrome - develop for the web
[!] Visual Studio - develop Windows apps       <- fine, we do not build the Windows target
[√] Connected device (Windows, Chrome, Edge)
[√] Network resources
```

(Android Studio does not even appear in the list when it is absent — that is fine.)

* **Android Studio "not installed" is fine.** It is an IDE convenience check, not a build
  requirement. Everything the build needs comes from `cmdline-tools` + `platform-tools`.
* **Visual Studio missing is fine.** That entry only gates *Windows desktop* builds, which this
  project does not target (`android, ios, web`).
* **`[!] Some Android licenses not accepted`** — re-run:
  `flutter doctor --android-licenses` and press `y` at each prompt.

---

## 5. Building

```powershell
cd D:\Programming\team_mausam_sih_2026\app

flutter pub get           # ~30 s first time
flutter analyze
flutter test
flutter build web         # output: app\build\web  (~40 s first time)
flutter build apk --debug # output: app\build\app\outputs\flutter-apk\app-debug.apk
```

**Android version floor: Android 7.0 (API 24).** `app/android/app/build.gradle.kts` sets
`minSdk = flutter.minSdkVersion`, which is **24** on Flutter 3.47. Do not hardcode 23: Flutter 3.47
runs `MinSdkVersionMigration` on every Android build and silently rewrites any hardcoded 16–23 back
to `flutter.minSdkVersion`. See the minSdk note in `docs/06_MOBILE_SPEC.md` §Android config.

### The first `flutter build apk` is slow — this is normal

The first Android build downloads the Gradle distribution (~130 MB), the Android Gradle Plugin,
and Kotlin/Java dependencies into `%USERPROFILE%\.gradle`. **Allow 8–30 minutes** and do not
interrupt it. Subsequent debug builds take 20–60 s.

If it looks frozen, it is almost certainly downloading — check:

```powershell
Get-ChildItem $env:USERPROFILE\.gradle\wrapper\dists -Recurse -File |
  Sort-Object LastWriteTime -Descending | Select-Object -First 3 Name, Length, LastWriteTime
```

### Serving the web build locally

```powershell
cd D:\Programming\team_mausam_sih_2026\app\build\web
C:\Python313\python.exe -m http.server 8080
# open http://localhost:8080
```

`flutter run -d chrome` is better for development (hot restart).

---

## 6. Running on a real phone (`adb`)

1. On the phone: **Settings → About phone → tap "Build number" 7×** to unlock Developer options.
2. **Settings → Developer options → USB debugging: ON** (and "Install via USB" on Xiaomi/Oppo).
3. Plug the phone in with a **data** cable (many charging cables have no data lines).
4. On the PC:

   ```powershell
   adb devices
   ```

   The first time, the phone shows an "Allow USB debugging?" dialog with an RSA fingerprint —
   tick "Always allow" and accept. Until you do, `adb devices` prints `unauthorized`.

5. Then:

   ```powershell
   cd D:\Programming\team_mausam_sih_2026\app
   flutter devices          # your phone should be listed
   flutter run              # or: flutter install
   ```

**Wireless (Android 11+, no cable after pairing):**

```powershell
# phone: Developer options -> Wireless debugging -> Pair device with pairing code
adb pair 192.168.1.42:41234        # enter the 6-digit code
adb connect 192.168.1.42:5555
```

**If the phone is not detected:** it is a *driver*, not a Flutter, problem. Most phones work with
the generic Windows MTP/ADB driver. For Xiaomi/Realme/Vivo you may need the OEM USB driver, which
does require admin to install — ask whoever administers the machine, or use an emulator/web build.
(This project's demo runs fine as a web build, so a phone is optional.)

---

## 7. Troubleshooting

### 7.1 Long paths (`Filename too long`, `path too long`, Gradle `CreateProcess error=206`)

Windows caps paths at 260 characters unless long-path support is enabled — and enabling it
system-wide **needs admin**. Avoid the problem instead:

* Keep the repo shallow: `D:\Programming\team_mausam_sih_2026` (already short) — do **not** move it
  under `C:\Users\<name>\Documents\...\OneDrive\...`.
* Keep the SDK at `D:\sdk` (short by design).
* If you hit it in `%USERPROFILE%\.gradle`, relocate the Gradle home to a short path:

  ```powershell
  setx GRADLE_USER_HOME D:\sdk\.gradle
  ```

  (open a new terminal afterwards).
* Git itself: `git config --global core.longpaths true` — this one is a *per-user* setting and
  needs no admin.

### 7.2 Developer Mode is **NOT** required

Flutter prints
`Building with plugins requires symlink support. Please enable Developer Mode in your system settings`
**only for Windows desktop builds**. This project targets `android, ios, web`, so:

* `flutter build web` — works with Developer Mode off.
* `flutter build apk` — works with Developer Mode off.
* `flutter build windows` — *would* need it. We do not build that target.

Do not go hunting for the Developer Mode toggle (it is also often disabled by corporate policy).
If a command nags about it, check that you are not accidentally building the Windows target.

### 7.3 `flutter` is not recognised

`setx` only affects **new** terminals. Open a new one, or dot-source `scripts\flutter_env.ps1`.
To confirm the variable actually landed:

```powershell
[Environment]::GetEnvironmentVariable('PATH','User') -split ';' | Select-String sdk
```

Absolute-path fallback that always works: `D:\sdk\flutter\bin\flutter.bat --version`.

### 7.4 `Unable to locate Android SDK` / `ANDROID_HOME` wrong

```powershell
flutter config --android-sdk D:\sdk\android
flutter config --jdk-dir D:\sdk\jdk-17
flutter doctor -v
```

Flutter stores this in `%USERPROFILE%\.config\flutter\settings` (older versions:
`%USERPROFILE%\.flutter_settings`), so it survives a PATH mess.

### 7.5 `C:` is nearly full

Move the two big caches off `C:` (both are plain user env vars, no admin needed):

```powershell
setx GRADLE_USER_HOME D:\sdk\.gradle
setx PUB_CACHE        D:\sdk\.pub-cache
```

### 7.6 Antivirus makes builds crawl

Real-time scanning on `D:\sdk\flutter`, `%USERPROFILE%\.gradle` and `app\build` can triple build
times. Adding exclusions in Windows Security needs admin; if you have none, expect the slower
numbers at the top of §5 and just be patient.

### 7.7 `sdkmanager` fails with a Java error

`sdkmanager.bat` reads `JAVA_HOME`. If another (older) JRE is installed and `JAVA_HOME` points at
it, the tool dies with `Could not find or load main class`. Force ours for the session:

```powershell
$env:JAVA_HOME = 'D:\sdk\jdk-17'
D:\sdk\android\cmdline-tools\latest\bin\sdkmanager.bat --sdk_root=D:\sdk\android --list
```

### 7.8 Corporate proxy / TLS interception

`curl.exe`, Gradle and `pub` each need their own proxy config:

```powershell
$env:HTTPS_PROXY = 'http://proxy.example:8080'
$env:HTTP_PROXY  = 'http://proxy.example:8080'
# Gradle additionally wants these in %USERPROFILE%\.gradle\gradle.properties:
#   systemProp.https.proxyHost=proxy.example
#   systemProp.https.proxyPort=8080
```

### 7.9 `java.io.IOException: Unable to establish loopback connection` from Gradle

**In a normal user terminal this does not happen — Gradle and `flutter build apk` work
out of the box.** It only shows up inside restricted shells (some CI containers, and machines
where a security product filters `%LOCALAPPDATA%\Temp`).

Root cause (confirmed with a 10-line JDK repro, not guesswork): JDK 17's `Selector.open()` builds
its internal pipe from an **AF_UNIX socket pair**, and it creates the socket file in
`java.io.tmpdir` (i.e. `%TEMP%`). When AF_UNIX socket files cannot be created there,
`UnixDomainSockets.connect0` fails with `SocketException: Invalid argument: connect`, which
`PipeImpl` reports as the misleading "Unable to establish loopback connection". Gradle cannot
start a single worker without a `Selector`.

Fix — point `TEMP`/`TMP` at a short path on a plain local disk for that one command:

```powershell
$env:TEMP = 'D:\sdk\tmp'; $env:TMP = 'D:\sdk\tmp'
mkdir D:\sdk\tmp -Force | Out-Null
flutter build apk --debug
```

```bash
TEMP='D:\sdk\tmp' TMP='D:\sdk\tmp' flutter build apk --debug   # Git Bash
```

Equivalent one-off JVM flag if you would rather not move `TEMP`:
`-Djdk.nio.channels.unixdomain.tmpdir=D:\sdk\tmp`.

Do **not** "fix" this with IPv4-only flags, `org.gradle.daemon=false`, or edits to
`app/android/gradle.properties` — none of them touch the cause, and the repo's
`gradle.properties` must stay at the Flutter defaults.

### 7.10 Starting over

```powershell
Remove-Item -Recurse -Force D:\sdk\flutter, D:\sdk\jdk-17, D:\sdk\android
powershell -ExecutionPolicy Bypass -File scripts\setup_flutter_windows.ps1
```

Downloads in `D:\sdk\_downloads` are reused, so a re-install is much faster than a first install.

---

## 8. Pointing the app at the backend over the LAN

`app/lib/core/config.dart` picks a default backend URL per platform:

| Where the app runs | Default backend URL |
|---|---|
| Chrome / web build on the dev PC | `http://localhost:8000` |
| Android **emulator** | `http://10.0.2.2:8000` (the emulator's alias for the host's `127.0.0.1`) |
| Real Android **phone** | the PC's LAN IP, e.g. `http://192.168.1.7:8000` — set it in **Settings → Backend URL** |

To serve the backend to a phone on the same Wi-Fi:

1. Bind uvicorn to all interfaces (not just localhost):

   ```powershell
   cd D:\Programming\team_mausam_sih_2026\backend
   .venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```

2. Find the PC's LAN IP:

   ```powershell
   Get-NetIPAddress -AddressFamily IPv4 |
     Where-Object { $_.InterfaceAlias -notmatch 'Loopback|vEthernet' } |
     Select-Object InterfaceAlias, IPAddress
   ```

3. Allow inbound TCP 8000 through Windows Firewall. **This needs admin** — the first time uvicorn
   binds, Windows shows a firewall prompt; if you cannot approve it, ask an administrator to run:

   ```powershell
   New-NetFirewallRule -DisplayName "Mausam backend 8000" -Direction Inbound `
     -Protocol TCP -LocalPort 8000 -Action Allow -Profile Private
   ```

   **Admin-free alternative:** reverse-tunnel instead of opening a port —
   `adb reverse tcp:8000 tcp:8000` makes the phone's `localhost:8000` hit the PC's `localhost:8000`
   over the USB cable. With that, leave the backend URL at `http://localhost:8000`.

4. On the phone, open the app → **Settings → Backend URL** → `http://192.168.1.7:8000` → Save.

Plain `http://` works because the Android manifest sets `android:usesCleartextTraffic="true"`
(see `app/android/app/src/main/AndroidManifest.xml`). That is deliberate for the demo; a
production build would use HTTPS and drop the flag.

**Quick check from the phone's browser** before blaming the app: open
`http://192.168.1.7:8000/health`. If that fails, it is the network/firewall, not Flutter.

---

## 9. Files in this repo that relate to setup

| File | Purpose |
|---|---|
| `scripts/setup_flutter_windows.ps1` | the installer described above (idempotent) |
| `scripts/flutter_env.ps1` | dot-source to fix up a running PowerShell session |
| `scripts/flutter_env.sh` | `source` to fix up a running Git Bash session |
| `.gitignore` | keeps `app/build`, `app/.dart_tool`, `android/.gradle`, `local.properties` out of git |
| `docs/06_MOBILE_SPEC.md` | normative Flutter/Android configuration |
