# Running the prototype

The long-form run guide for Team Mausam's SIH 2026 prototype (PS 26076): the FastAPI backend,
every way of running the Flutter app (Chrome, a real Android phone, a pre-built APK, the Android
emulator, the home-screen widget, iOS), the CI workflows, the five-minute demo walk-through and
the toolchain problems we actually hit. Nothing here needs an API key, a Docker daemon or a
database server.

## Prerequisites

| Need | For | Notes |
|---|---|---|
| **Python 3.13** | backend | any 3.13.x; the venv lives at `backend/.venv` |
| **Flutter stable 3.47.x** | app | <https://docs.flutter.dev/get-started/install>, then `flutter doctor` |
| **Chrome** | app option (a) | the only tick `flutter doctor` needs for the web loop |
| **Android toolchain** (Android Studio's SDK + JDK 17) | app options (b)–(e) | `flutter doctor --android-licenses` accepts the licences |
| **macOS + Xcode** | app option (f) only | plus CocoaPods and a simulator runtime |

Nothing below needs administrator rights except the emulator's one-time virtualization step in
(d). On Windows, read [`SETUP_WINDOWS.md`](SETUP_WINDOWS.md) first — it installs the whole
toolchain under `D:\sdk\` without admin rights.

## 1. Backend

```bash
cd backend
python -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt   # Windows: .venv\Scripts\python
.venv/bin/python -m pytest -q                             # → 386 passed (fully offline)
.venv/bin/python -m uvicorn app.main:app --reload --port 8000
```

| What | URL |
|---|---|
| Health | <http://localhost:8000/api/v1/health> |
| OpenAPI docs | <http://localhost:8000/docs> |
| **Admin demo console** | <http://localhost:8000/admin/console> — paste the admin key `mausam-admin` and press **Save** |
| Live alerts | `ws://localhost:8000/ws/alerts?token=&lat=28.61&lon=77.21` |

Routers are mounted at `/api/v1` **and** at the root, so `curl http://localhost:8000/health` works
too. SQLite is created on first boot at `backend/data/mausam.db`. Configuration, environment
variables, the admin console panels, the ML ranker and the Docker / Render deploy path are in
[`backend/README.md`](../backend/README.md).

Smoke test with a guest token:

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/guest | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/home?lat=28.61&lon=77.21&personas=parent,commuter&now_override=$(date +%F)T07:30:00+05:30"
```

`$(date +%F)` is deliberate — the demo clock has to land inside the 48-h forecast window or the
*ranking* moves while the *reading* stays on the live observation (see
[§4 Demo walk-through](#4-demo-walk-through)). A hardcoded date makes the clock look like it does
nothing.

**Docker / Render.** `cd infra && docker compose up --build` builds
[`backend/Dockerfile`](../backend/Dockerfile) and serves on port 8000;
[`infra/render.yaml`](../infra/render.yaml) is a Render Blueprint for the free tier. Both, with
the free-plan caveats (sleeps after ~15 min idle, ephemeral disk), are in
[`backend/README.md`](../backend/README.md) §Deploy.

## 2. App

**Never used Flutter before?** Install the SDK once — pick **stable 3.47.x** — then run
`flutter doctor`. For option (a) you only need the **Chrome** tick; options (b)–(e) also need the
**Android toolchain** tick.

```bash
cd app
flutter pub get
flutter analyze          # "No issues found!"
flutter test             # 125 green, incl. the fixture contract test
```

### (a) Chrome — the fastest loop, no Android toolchain

```bash
cd app && flutter run -d chrome
```

Press `r` to hot-reload, `R` to restart, `q` to quit. The default backend URL is
`http://localhost:8000`; if the app shows "Sample data" it could not reach the backend — start it
(step 1) or fix **Settings → Backend URL**.

### (b) A real Android phone over USB — the best demo

1. On the phone: **Settings → About phone → tap "Build number" seven times** to unlock
   *Developer options*, then **Developer options → USB debugging → on**.
2. Plug it into the laptop with a **data** cable and accept the *Allow USB debugging?* RSA prompt
   on the phone (tick "always allow").
3. Check the laptop can see it, then run:

```bash
cd app && flutter devices        # your handset should be listed, e.g. "SM_A155F (mobile)"
cd app && flutter run            # or: flutter run -d <device-id> when more than one is attached
```

If `flutter devices` shows nothing, re-plug the cable, confirm the prompt on screen, and run
`adb devices` (`unauthorized` = the prompt was not accepted; `no permissions` on Linux = add the
udev rule). Then set **Settings → Backend URL** in the app to `http://<your-laptop-LAN-IP>:8000`
(see (g)) — a phone cannot reach the laptop's `localhost`. Windows driver problems and wireless
`adb` pairing: [`SETUP_WINDOWS.md`](SETUP_WINDOWS.md) §6.

### (c) Install the APK directly

No Flutter toolchain is needed on the machine that installs it.

*From CI, no build needed:* open the repo's
[**Actions → flutter**](https://github.com/Shreyansh303/team_mausam_sih_2026/actions/workflows/flutter.yml)
run for the commit you want → **Artifacts → `app-release-apk`** → download and unzip →
`app-release.apk`. (GitHub requires you to be signed in to download artifacts.)

*Or build it yourself:*

```bash
cd app && flutter build apk --release      # ~2 min warm; debug signing, fine for a demo
# → app/build/app/outputs/flutter-apk/app-release.apk   (62.5 MB, all ABIs)
adb install -r build/app/outputs/flutter-apk/app-release.apk
# a debug build also works and is what you want for logs:
cd app && flutter build apk --debug        # → app-debug.apk (~168 MB)
```

The first Gradle run downloads ~2.7 GB into `~/.gradle` and takes several minutes; see §5 if
the wrapper cannot fetch its own distribution.

**Bake the backend URL into the build — do this for any APK you hand to someone else.**
On Android the app otherwise defaults to `http://10.0.2.2:8000`, which is the *emulator's* alias for
the host loopback and resolves to nothing on a real phone: the app falls back to its bundled sample
payload and shows a "Sample data" banner. `--dart-define=BACKEND_URL=<origin>` sets the default
origin at compile time ([`app/lib/core/config.dart`](../app/lib/core/config.dart)), so the app
talks to a real backend on first launch with no trip through Settings:

```bash
# phone and laptop on the same Wi-Fi — use the LAN IP, never localhost.
# find it with: ipconfig (Windows) · ipconfig getifaddr en0 (macOS) · hostname -I (Linux)
cd app && flutter build apk --release --dart-define=BACKEND_URL=http://192.168.1.20:8000

# or a deployed backend
cd app && flutter build apk --release --dart-define=BACKEND_URL=https://<service>.onrender.com
```

Pass the **origin only** — the app appends `/api/v1` and derives `ws://`/`wss://` itself.

**Verify it landed** by searching the compiled Dart snapshot — the APK is a zip, so grepping the
`.apk` itself finds nothing:

```bash
cd app/build/app/outputs/flutter-apk
unzip -o -q app-release.apk 'lib/arm64-v8a/libapp.so' -d /tmp/apkcheck
grep -ac 'http://192.168.1.20:8000' /tmp/apkcheck/lib/arm64-v8a/libapp.so   # 1 = baked in
```

**Settings → Backend URL still overrides it**, which is what you want when the laptop's DHCP lease
changes the IP. Serving over plain `http://` works because `android:usesCleartextTraffic="true"`
is set for the prototype; a real deployment should be HTTPS and drop that flag.

To install without `adb`, copy the `.apk` to the phone and open it — Android asks you to allow
"install unknown apps" for the file manager first. The app is signed with the **debug** key
(`flutter build apk --release` falls back to it when no keystore is configured), so it installs
side-by-side with nothing and can be uninstalled normally.

**Sign it with your own key** (needed only to publish): create a keystore **outside the repo** and
point `app/android/key.properties` at it — both are gitignored, and `app/android/app/build.gradle.kts`
picks the key up on the next `--release` build (it prints a warning when the file is absent):

```bash
keytool -genkey -v -keystore ~/mausam-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mausam
# app/android/key.properties — storeFile absolute, or relative to app/android/app/
printf 'storeFile=%s\nstorePassword=CHANGEME\nkeyAlias=mausam\nkeyPassword=CHANGEME\n' ~/mausam-release.jks > app/android/key.properties
```

### (d) Android emulator — optional, and the least-travelled path

It needs a ~1.5 GB system image plus the emulator package (~1 GB), so skip it unless you have no
phone. Helper scripts ([`scripts/setup_android_emulator.*`](../scripts/setup_android_emulator.sh),
[`scripts/run_emulator.*`](../scripts/run_emulator.sh)) create and boot an AVD called
`mausam_pixel`; the SDK root comes from `ANDROID_HOME`, then `ANDROID_SDK_ROOT`, then the
platform default:

```powershell
# Windows (PowerShell 5.1+)
.\scripts\setup_android_emulator.ps1      # sdkmanager: emulator + system image; avdmanager: AVD
.\scripts\run_emulator.ps1                # boots it and waits for sys.boot_completed
```

```bash
# macOS / Linux
./scripts/setup_android_emulator.sh       # picks arm64-v8a on Apple Silicon, x86_64 otherwise
./scripts/run_emulator.sh
```

```bash
cd app && flutter run -d emulator-5554    # backend URL: http://10.0.2.2:8000
```

Stop the emulator by closing its window or with `adb emu kill`.

**One-time administrator step for the emulator on Windows:** hardware acceleration needs the
**Windows Hypervisor Platform** feature (Windows Features, or
`dism /online /Enable-Feature /FeatureName:HypervisorPlatform /All` from an elevated prompt, then
reboot) **and** virtualization enabled in the BIOS/UEFI (Intel VT-x / AMD SVM). Without it the
emulator either refuses to start or is unusably slow. macOS needs nothing; Linux needs KVM
(`sudo apt install qemu-kvm`, add yourself to the `kvm` group). This is the only step in the whole
repo that asks for admin rights — the setup script's header repeats it.

### (e) The home-screen widget (Android, optional)

Once the app is installed and has loaded the feed once, long-press an empty spot on the home
screen → **Widgets** → **Mausam Personalized**, and drag the 4x1 or 4x2 tile out. It shows the
last `/home` payload — temperature, condition, location, how old the reading is, and the top
pinned card in its severity colour — refreshes itself about once an hour, and opens the app (or
that card's detail) when tapped. Details and limits:
[`06_MOBILE_SPEC.md`](06_MOBILE_SPEC.md) §Home-screen widget.

### (f) iOS

iOS builds and simulators require **macOS with Xcode** (plus CocoaPods and a simulator runtime —
`sudo gem install cocoapods`, and install a runtime from Xcode → Settings → Components). The code
is platform-neutral and `flutter run -d iphone` works once `flutter doctor` is happy about Xcode,
but there is no iOS build in CI and judges are expected to use the Android APK or Chrome. An
Xcode `[!]` line in `flutter doctor` does not affect any Android or web build.

### (g) Backend URL rules

The app stores the backend **origin** only (it appends `/api/v1` and derives `ws://`/`wss://`
itself), and **Settings → Backend URL** overrides the default:

| Where the app runs | Backend URL |
|---|---|
| Flutter web / desktop on the same machine | `http://localhost:8000` |
| Android **emulator** on the same machine | `http://10.0.2.2:8000` |
| Real Android phone on the same Wi-Fi | `http://<laptop-LAN-IP>:8000` |
| Deployed backend | `https://<service>.onrender.com` |

Find the LAN IP with `ipconfig` (Windows, "IPv4 Address"), `ipconfig getifaddr en0` (macOS) or
`hostname -I` (Linux) — something like `192.168.1.23`. Start the backend so it listens on that
interface (`uvicorn app.main:app --host 0.0.0.0 --port 8000`), keep the phone on the **same Wi-Fi**,
and check `http://<laptop-LAN-IP>:8000/api/v1/health` in the phone's browser before blaming the app.
A firewall prompt on first run must be allowed for private networks (on Windows without admin
rights, `adb reverse tcp:8000 tcp:8000` tunnels the phone's `localhost:8000` over USB instead —
[`SETUP_WINDOWS.md`](SETUP_WINDOWS.md) §8). `CORS_ORIGINS=*` is the default, so Flutter web works
with no proxy.

**OS differences in one line:** the venv interpreter is `backend/.venv/bin/python` on macOS/Linux
and `backend\.venv\Scripts\python.exe` on Windows; Windows also needs
[`SETUP_WINDOWS.md`](SETUP_WINDOWS.md) (toolchain install, and §7.9 for the Gradle `TEMP` recipe).

## 3. CI

Two GitHub Actions workflows, both offline (no API key, no network):

- [`.github/workflows/backend.yml`](../.github/workflows/backend.yml) — on every push/PR that
  touches `backend/`: Python 3.13, `pip install -r requirements-dev.txt`, an import check of
  `app.main`, then `python -m pytest -q`.
- [`.github/workflows/flutter.yml`](../.github/workflows/flutter.yml) — on every push/PR that
  touches `app/`: Flutter 3.47.2 stable + Temurin JDK 17, `flutter pub get`, `flutter analyze`,
  `flutter test`, `flutter build apk --release` (debug signing) and, in a second job,
  `flutter build web`.

The release APK is uploaded as the artifact **`app-release-apk`** (kept 30 days), the web build as
**`web-build`** (7 days). Both workflows can be started by hand from the Actions tab
(`workflow_dispatch`). The runner installs the `compileSdk = 37` platform on demand.

## 4. Demo walk-through

About five minutes. Backend running, admin console open on a laptop, app open on a phone or in
Chrome.

1. **Onboard** — language → pick **Parent + Commuter** → location **Delhi** (GPS, search or a
   popular city).
2. **Morning home** — set the demo clock to **07:30** (app demo sheet, admin console, or
   `?now_override=<today>T07:30:00+05:30`). Use **today's** date: the backend only moves the
   *reading* to a demo hour it has a forecast row for, and leaves the live observation standing
   otherwise, so a stale date makes the clock look like it does nothing. *School run* and
   *Commute conditions* rank first, each with its reasons; hero shows current conditions, nowcast
   and any rain alert below.
3. **Switch persona** — tap the **Fitness** chip: best workout window, sun times, wind and heat
   alert move up. Then **Health**: AQI, pollen, UV, humidity.
4. **Change location to Goa** — sea conditions, tides (**Estimated**) and water temperature appear;
   they are gated on the location being coastal.
5. **Push a warning** — admin console → preset **Orange thunderstorm — Delhi** → *Push warning*. The
   app receives `warning_issued` with `affects_you: true`, shows the banner and **animates the
   warning card to the top**. Delete the row to revert (or let its TTL expire).
6. **Show the learning** — long-press *Pollen* → *Why am I seeing this?* → *Show less*. Each tap
   subtracts from the card's score ([`03_PERSONALIZATION_ENGINE.md`](03_PERSONALIZATION_ENGINE.md):
   `0.25·tanh(x/8)`, so two taps are −0.16) and the sheet shows the running count; keep tapping
   until it drops into "More for you" — **two taps move it, three usually push it over**, because
   how far it has to fall depends on the cards around it. *Pin* is the instant one: the card jumps
   to the top on the next refresh, *Unpin* puts it back.
7. **Offline** — airplane mode: the home still renders from cache with "Updated N min ago".
8. **Hindi** — switch language; chrome *and* card copy/insights are localized.
9. **Traveller** — saved places Mumbai + London → packing suggestions ("Carry a raincoat in
   London") and flight-risk alerts.
10. Close on the architecture: server-driven cards, provider fallback chain, explainable engine.

The same script is in [`00_VISION.md`](00_VISION.md) §Judge demo script; the admin console's
panels and the 60-second warning-push variant are in [`backend/README.md`](../backend/README.md)
§Demo console.

### Scenario overlays

Overlays replace live weather with a scripted situation — `heatwave`, `cyclone`, `dense_fog`,
`frost`, `severe_aqi`, `thunderstorm`, `heavy_rain`, `monsoon_flood`, `clear_pleasant`, `live`.
Set one globally from the admin console (it broadcasts `scenario_changed` to every connected
client), or per request:

```bash
# scenario + demo clock on a single request (both also accepted by /weather/snapshot)
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/home?lat=28.61&lon=77.21&personas=commuter&scenario=dense_fog"
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/home?lat=28.61&lon=77.21&personas=parent&now_override=$(date +%F)T07:30:00+05:30"
```

### `now_override` rules

`now_override` is ISO-8601; a value without an offset is read as IST. `POST /admin/now-override`
with `{"now": null}` clears the demo clock (the console's **Clear** button does the same). Keep the
date inside the 48-h forecast window — today or tomorrow: outside it the *ranking* still moves but
the reading stays on the live observation rather than inventing one (the app's demo sheet builds
its presets on today for this reason).

## 5. Troubleshooting

### The app shows a "Sample data" banner

The banner reads "Sample data — the backend at `<url>` is not reachable." It means exactly that:
the app could not reach the backend origin it was given and is rendering its bundled sample
payload (`app/assets/fixtures/home_sample.json`, a `/home` response for New Delhi) instead. It is
not a crash. Check, in order: the backend is running (`curl http://localhost:8000/api/v1/health`);
the URL matches the table in (g) — on a real phone `localhost` and `10.0.2.2` both point at the
phone itself; the phone is on the same Wi-Fi and the backend was started with `--host 0.0.0.0`;
the firewall let port 8000 through. Fix **Settings → Backend URL** and pull to refresh.

### The Gradle wrapper cannot download its own distribution (macOS, some networks)

`gradlew` fetches `https://services.gradle.org/distributions/gradle-9.3.1-all.zip`, which
redirects to GitHub release assets. That hostname resolves to several addresses; on one network we
used, one of them refused TCP 443, and the JVM tries only the first address it is handed, so the
build dies with `java.net.ConnectException: Connection refused` inside
`org.gradle.wrapper.Download`. `curl` retries the other addresses and succeeds, so download the
zip yourself into the cache slot the wrapper created on its failed attempt
(`ls ~/.gradle/wrapper/dists/gradle-9.3.1-all/` shows the one hashed directory):

```bash
cd ~/.gradle/wrapper/dists/gradle-9.3.1-all/9ot9r568e8zfvvd4mn8rbu1j0 \
  && curl -fL --retry 5 --retry-all-errors -o gradle-9.3.1-all.zip \
     https://services.gradle.org/distributions/gradle-9.3.1-all.zip
```

Expected sha256: `17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43` (published
next to the zip as `gradle-9.3.1-all.zip.sha256`). The wrapper skips the download when the zip is
already there. Redo this if `~/.gradle` is ever wiped or the wrapper version in
`app/android/gradle/wrapper/gradle-wrapper.properties` changes.

### `compileSdk 37` and `Failed to find target with hash string 'android-37'`

`app/android/app/build.gradle.kts` pins `compileSdk = 37` because `permission_handler_android`
14.1.0 requires it (Flutter 3.47's own default is 36); without the pin `assembleDebug` fails the
AAR-metadata check ("Dependency ':permission_handler_android' requires … version 37 or later").
AGP 9.1.0's "maximum recommended compile SDK … is 36" is a warning only.

`sdkmanager` currently publishes the platform as `platforms;android-37.0`, and AGP auto-installs it
under `platforms/android-37.0`, but then looks for the legacy name `android-37` and stops with
`Failed to find target with hash string 'android-37'`. Give it that directory once:

- **Windows:**
  `New-Item -ItemType Junction -Path D:\sdk\android\platforms\android-37 -Target D:\sdk\android\platforms\android-37.0`
  (no admin needed; adjust the SDK root if yours is not `D:\sdk\android`).
- **macOS / Linux:** copy `platforms/android-37.0` to `platforms/android-37` and, in the copy,
  change `AndroidVersion.ApiLevel=37.0` to `37` in `source.properties` and
  `path="platforms;android-37.0"` / `<api-level>37.0</api-level>` to `android-37` / `37` in
  `package.xml`. Keep both directories.

This is a local-SDK quirk; the CI runner needs nothing.

### Android SDK maintenance (macOS / Linux, command-line tools only)

The classic `sdkmanager` is what `flutter doctor` and the emulator scripts expect. Recent
`cmdline-tools;latest` releases (22.0, 23.0) replace it with a new `android` CLI and a deprecation
shim that hangs on `sdkmanager --install` from a non-interactive shell and prints warning lines
before `--version`. Keep **cmdline-tools 21.0** as `cmdline-tools/latest`
(`https://dl.google.com/android/repository/commandlinetools-mac-15641748_latest.zip` on macOS)
and do not upgrade it. With 21.0 in place:

```bash
# Android SDK maintenance
yes | ~/development/android/cmdline-tools/latest/bin/sdkmanager \
      --sdk_root="$HOME/development/android" --licenses
```

`yes | sdkmanager --sdk_root=$ANDROID_HOME <pkgs>` installs packages the same way. The SDK
components that matter are `platforms;android-36`, `build-tools;36.0.0` and
`platforms;android-37.0` (+ the alias above); a 35-only SDK will not build this app. On macOS,
`/usr/bin/java` is Apple's stub ("Unable to locate a Java Runtime") — point `JAVA_HOME` at a real
JDK 17 (Temurin works). Disk: Flutter ≈3.9 GB, Android SDK ≈1.5 GB, JDK ≈0.3 GB, the first APK
build ≈2.8 GB under `~/.gradle`, `app/build` ≈0.4 GB (`flutter clean` reclaims it).

### Serving the web build locally

`flutter run -d chrome` is the development loop. To serve a built `app/build/web` — for a
screenshot pass or a machine without Flutter — bind the static server to **127.0.0.1** and open
that literal address, not `localhost` (a browser may resolve `localhost` to IPv6 `::1`, which an
IPv4-bound server is not listening on):

```bash
cd app && flutter build web
cd app/build/web && python3 -m http.server 8080 --bind 127.0.0.1   # then open http://127.0.0.1:8080
```

### Windows

Everything Windows-specific — long paths, `flutter` not recognised, `ANDROID_HOME` wrong,
antivirus, corporate proxies, starting over — is in [`SETUP_WINDOWS.md`](SETUP_WINDOWS.md) §7.
Its §7.9 covers the Gradle error `java.io.IOException: Unable to establish loopback connection`
(`TEMP` on a folder where JDK 17 cannot create its AF_UNIX socket file; fix: a short local `TEMP`
for that one command, never an edit to `app/android/gradle.properties`). The `android-37`
junction above is the other Windows-only item.
