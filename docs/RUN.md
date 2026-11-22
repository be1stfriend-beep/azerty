# Running Piggyback Planet

## How the game connects
- Listen server: one device **hosts** and also plays; the other device **joins** it. No internet server is involved.
- The joiner types the host's local IP address (for example `192.168.1.23`). Traffic is UDP on port **7777**.
- Both devices must be on the same Wi-Fi network (or the same phone hotspot).
- Login screen: type a name, then "Host as Bjorn" / "Host as Imad" on one device and "Join" on the other.

## Setting up on a new PC (after git clone)
1. Install Godot **4.7.2** and Python 3.
2. Copy `local.env.example` to `local.env` and set `GODOT_BIN` (and `ANDROID_HOME` for phone builds).
   `local.env` is gitignored, so each PC keeps its own paths. A real `GODOT_BIN` environment variable overrides it.
3. Run `python tools/run_two.py`. The first run imports the assets once (the `.godot/` cache is not in git).
   Opening the project in the Godot editor does the same import.

## Test on PC (no phone needed)
```
python tools/run_two.py
```
Opens two game windows side by side on this PC. The left one hosts, the right one joins `127.0.0.1` (this PC).
For testing only; it is not used for phones. Needs `GODOT_BIN` set to the Godot 4.7.2 executable.
Extra arguments are passed to both windows, e.g. `python tools/run_two.py --touch` shows the touch buttons.

PC keys: WASD move, arrows aim, E action, Space jump, J kick, M mount, N dismount. F3 or the NET button shows ping and loss.
Self-test without network: `& $env:GODOT_BIN --headless --path . -- --autotest-slice` (prints PASS/FAIL).

## One-time Android setup
1. Godot editor > Editor > Manage Export Templates: version **4.7.2.stable** installed (Android templates included).
2. Editor > Editor Settings > Export > Android:
   - Java SDK Path: the JDK 17 folder, e.g. `C:\Program Files\Eclipse Adoptium\jdk-17...`
   - Android SDK Path: e.g. `C:\Users\<you>\AppData\Local\Android\Sdk`
   - Debug Keystore: Godot creates one in `%APPDATA%\Godot\keystores\debug.keystore` (user `androiddebugkey`, password `android`).
3. The project already has the "Android" preset (`export_presets.cfg`): package `com.piggyback.planet`, arm64-v8a, landscape, network permissions, no Gradle build.
4. On each phone: Settings > About phone > tap "Build number" 7 times; then Developer options > **USB debugging** on.
   Plug in by USB, unlock the phone, and accept "Allow USB debugging" (tick "Always allow").

## Build and install
```
python tools/build_android.py --launch
```
Exports `builds/piggyback-debug.apk`, installs it on **every** connected, authorised phone, and starts it.
`--no-install` only exports. Plug both phones in at once, or run it once per phone.
`adb` is found on PATH, in `ANDROID_HOME`, or in the SDK path from the Godot editor settings.

## Playing over Wi-Fi
**Scenario A: the PC hosts and plays, one phone joins.**
1. On the PC: `& $env:GODOT_BIN --path .` then "Host as ...".
2. Read the host IP in the login screen Network panel (or run `ipconfig`, "IPv4 Address" of the Wi-Fi adapter).
3. On the phone: type that IP and press Join.

**Scenario B: one phone hosts, the other phone (or the PC) joins.**
1. Phone 1: "Host as ...". Its Network panel shows its IP (also in Android Settings > Wi-Fi > network details).
2. Phone 2 or the PC: type that IP, Join.

Network checklist (do these once):
- Windows firewall, admin PowerShell, needed whenever the PC hosts:
  `New-NetFirewallRule -DisplayName "Piggyback" -Direction Inbound -Protocol UDP -LocalPort 7777 -Action Allow`
- Windows Wi-Fi network profile set to **Private** (Settings > Network > Wi-Fi > your network).
- **Mobile data OFF** on the phones, or Android may send game traffic over 4G/5G.
- Router **client isolation / AP isolation / guest network OFF**: it blocks devices from seeing each other. A phone hotspot works as a fallback.

## Troubleshooting
| Symptom | Likely cause | Fix |
|---|---|---|
| Cannot connect at all | Wrong IP, or different networks | Use the IP shown on the host's Network panel; both on the same Wi-Fi |
| Timeout message after Join | Firewall, Public profile, client isolation, mobile data | Add the firewall rule, set Private, turn isolation and mobile data off, try a phone hotspot |
| Joins only when the PC is the client | PC firewall blocks inbound UDP 7777 | Add the firewall rule (admin PowerShell) |
| App crashes at start | APK built with a different Godot version or missing data | Rebuild with `python tools/build_android.py`; check `adb logcat -s godot` |
| Black screen on the phone | GPU without OpenGL ES 3, or still loading | Wait 10 s; check `adb logcat -s godot`; the game uses the Compatibility renderer |
| Installed but old version | Install failed silently, or a different package | Read the script output for "installed"; uninstall with `adb uninstall com.piggyback.planet`, rerun |
| adb does not see the phone | USB debugging off, charge-only cable, prompt not accepted | Enable USB debugging, use a data cable, accept the prompt, set USB mode to "File transfer" |
| Device shows "unauthorized" | Debug prompt not accepted | Unlock the phone, accept "Allow USB debugging", rerun |
| Export fails: missing template | Templates not installed for 4.7.2 | Editor > Manage Export Templates > Download and Install |
| Export fails: SDK / Java / keystore error | Editor Settings paths empty or wrong | Set Java SDK, Android SDK and Debug Keystore in Editor Settings > Export > Android |
| Export fails: ETC2/ASTC required | Texture compression off | Already on in project.godot (`import_etc2_astc=true`); run `& $env:GODOT_BIN --headless --path . --import` |
