# Whispr — Setup Instructions

Complete guide to get the app running locally, and to deploy the Cloudflare Worker.

---

## Prerequisites

| Tool | Min version | Install |
|------|-------------|---------|
| Flutter | 3.22+ | https://docs.flutter.dev/get-started/install |
| Dart | 3.3+ | bundled with Flutter |
| Xcode | 15+ | Mac App Store (iOS only) |
| Android Studio | 2023+ | https://developer.android.com/studio |
| Node.js | 18+ | https://nodejs.org |
| Wrangler CLI | 3+ | `npm install -g wrangler` |

---

## 1. Clone & install dependencies

```bash
flutter pub get
```

If you see Hive adapter errors, regenerate them:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 2. Notification sound assets

The app ships its own chime sound (Section 7.1a). You need two files:

| File path | Format | Platform |
|-----------|--------|----------|
| `assets/sounds/whispr_chime.caf` | .caf or .aiff, < 30 s | iOS |
| `assets/sounds/whispr_chime.ogg` | .ogg or .mp3, < 5 s | Android |
| `android/app/src/main/res/raw/whispr_chime.ogg` | same file, copy here | Android channel |

**Source:** commission or license a short (0.5–1.5 s) soft chime. A placeholder
silence file works for development — just replace before shipping.

---

## 3. Cloudflare Worker (the callAI function)

The Worker is in `cloudflare_worker/`. It holds the OpenRouter API key and
forwards requests; it stores nothing.

### Deploy

```bash
cd cloudflare_worker
npm install -g wrangler   # if not already installed
wrangler login
wrangler deploy
```

Wrangler will print your Worker URL:
```
https://whispr-callai.YOUR-SUBDOMAIN.workers.dev
```

### Set the API key secret

```bash
wrangler secret put OPENROUTER_API_KEY
# Paste your OpenRouter key when prompted. Never commit it to source control.
```

Get an OpenRouter key at https://openrouter.ai/keys (free tier available).

### Point the Flutter app at your Worker

Open `lib/services/cloudflare_worker_service.dart` and set `_workerUrl`:

```dart
static const String _workerUrl =
    'https://whispr-callai.YOUR-SUBDOMAIN.workers.dev';
```

### Choose your models

In `cloudflare_worker/worker.js`, adjust the model strings to match your
OpenRouter account's access and your latency/cost preferences:

```js
const PRIMARY_MODEL  = 'anthropic/claude-3-5-haiku';   // fast + cheap
const FALLBACK_MODEL = 'openai/gpt-4o-mini';           // backup
```

Test both against the Section 12 test cases before locking them in.

---

## 4. Android setup

### 4.1 Merge AndroidManifest additions

Open `android/app/src/main/AndroidManifest.xml` and merge the snippets from
`android_foreground_service/AndroidManifest_additions.xml`:
- Permissions block (before `<application>`)
- `CountdownForegroundService` declaration (inside `<application>`)
- `flutter_local_notifications` receivers (inside `<application>`)

### 4.2 Add the Foreground Service

Copy `android_foreground_service/CountdownForegroundService.kt` into:
```
android/app/src/main/kotlin/com/whispr/app/CountdownForegroundService.kt
```

### 4.3 Replace MainActivity

Copy `android_foreground_service/MainActivity.kt` into:
```
android/app/src/main/kotlin/com/whispr/app/MainActivity.kt
```

### 4.4 Notification sound

Copy the `.ogg` sound file into:
```
android/app/src/main/res/raw/whispr_chime.ogg
```
Create the `raw/` directory if it doesn't exist.

---

## 5. iOS setup

### 5.1 Notification sound

Copy the `.caf` sound file into:
```
ios/Runner/Resources/whispr_chime.caf
```
Add it to the Runner target in Xcode (drag into project navigator, tick "Add to
targets: Runner").

### 5.2 Live Activity widget extension

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File → New → Target → Widget Extension** — name it `WhisprWidget`.
   - Uncheck "Include Configuration App Intent".
3. Copy `ios_live_activity/WhisprLiveActivity.swift` into the `WhisprWidget/` group.
4. Delete the placeholder `WhisprWidgetBundle.swift` Xcode generates and replace
   it with the entry in `WhisprLiveActivity.swift` (the `WhisprWidget: Widget` struct).
5. In the `WhisprWidget` target's **Info.plist**, add:
   ```
   NSSupportsLiveActivities → YES (Boolean)
   ```
6. In **Signing & Capabilities** for BOTH the Runner target AND the WhisprWidget
   target, add the **App Groups** capability and create/select:
   ```
   group.com.whispr.app.shared
   ```

### 5.3 Replace AppDelegate

Copy `ios_live_activity/AppDelegate.swift` over `ios/Runner/AppDelegate.swift`.
This adds the MethodChannel bridge that wires Flutter → ActivityKit.

### 5.4 iOS permissions (Info.plist)

Add to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Whispr uses the microphone to record voice reminders.</string>
```

### 5.5 Build & test on device

Live Activities do not render in the simulator on older Xcode versions.
Use a real device for Section 7.5 testing.

```bash
flutter run --release -d <device-id>
```

---

## 6. Run the app

```bash
# Android
flutter run -d android

# iOS (requires Xcode + signing configured)
flutter run -d ios
```

---

## 7. Environment variables summary

| Variable | Where set | Value |
|----------|-----------|-------|
| `OPENROUTER_API_KEY` | Cloudflare Worker secret (`wrangler secret put`) | Your OpenRouter key |
| `_workerUrl` | `lib/services/cloudflare_worker_service.dart` | Your Worker URL |
| `PRIMARY_MODEL` | `cloudflare_worker/worker.js` | OpenRouter model string |
| `FALLBACK_MODEL` | `cloudflare_worker/worker.js` | OpenRouter model string |

---

## 8. Testing the AI pipeline

Use the Section 12 test cases from the implementation plan. Run each input
through the app and verify the output matches the expected result:

| Input | Expected |
|-------|----------|
| "mene subha 10 bje gari saaf karni hae 30 min pehle yad kra dena" | ready — Wash car, 9:30 AM trigger |
| "thori dair me yaad kra dena" | needs_clarification with quick replies |
| "medicine 2pm aur 5pm pe yaad krana" | ready — 2 triggers on one reminder |
| (silence / background noise) | Error: "Didn't catch that — try again?" |

---

## 9. Data backup notice

All reminders are stored on-device in Hive. Uninstalling the app removes them.
There is no cloud backup by design (Section 4). Consider adding an export feature
before releasing to real users.

---

## 10. Hive schema migration

If you change `lib/models/*.dart` after shipping, increment the `typeId` on
any new fields and update the corresponding `.g.dart` adapter manually (or
re-run `build_runner`). Test on a device with existing data before releasing.
