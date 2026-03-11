# LifeLens - Build Instructions

## What This App Does

LifeLens is your personal life intelligence system. It runs 24/7 in the background and tracks:

- **Every app you open** - exact time, duration, category
- **Where you physically are** - GPS, address, inferred place name
- **Your physical activity** - steps, walking, running, driving
- **Screen on/off** - how many times you pick up your phone
- **WiFi/network context** - home? office? cafe?

Then **Claude AI** analyzes all of it and gives you:
- A minute-by-minute timeline of your day
- An honest daily narrative of how you spent your time
- Productivity + Wellbeing scores (0-100)
- Weekly pattern analysis
- Specific recommendations

---

## Prerequisites

Install these first:

1. **Flutter SDK** (3.16+): https://docs.flutter.dev/get-started/install
2. **Android Studio** or **VS Code** with Flutter extension
3. **Android SDK** (via Android Studio)
4. **Java 17+**: Already included with Android Studio

---

## Setup Steps

### 1. Clone and navigate
```bash
cd life_lens
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Add your Claude API key
- Open the app → Settings → paste your API key from console.anthropic.com

### 4. Grant Android permissions (CRITICAL)
After first launch, you MUST manually grant:

**Usage Access (most important):**
1. Go to Android Settings → Apps → Special app access → Usage access
2. Find LifeLens → Enable it

**Background Location:**
1. Settings → Apps → LifeLens → Permissions → Location
2. Select "Allow all the time"

---

## Build the APK

### Debug APK (for testing):
```bash
flutter build apk --debug
```
APK will be at: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (for daily use):
```bash
flutter build apk --release
```
APK at: `build/app/outputs/flutter-apk/app-release.apk`

### Install directly to connected phone:
```bash
flutter run
# or
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Architecture

```
lib/
├── main.dart                    # App entry point + background service init
├── models/
│   ├── life_event.dart          # Every tracked event (app, location, step, etc.)
│   └── daily_summary.dart       # AI-generated daily summary + weekly report
├── database/
│   └── database_helper.dart     # SQLite - all data stored locally
├── services/
│   ├── background_service.dart  # 24/7 background tracking orchestrator
│   ├── usage_stats_service.dart # App usage via Android UsageStats API
│   ├── location_service.dart    # GPS + reverse geocoding
│   ├── step_service.dart        # Pedometer step counting
│   └── screen_service.dart      # Screen on/off detection
├── ai/
│   └── claude_service.dart      # Claude API integration (summaries, insights)
└── screens/
    ├── onboarding_screen.dart   # First-launch permissions flow
    ├── home_screen.dart         # Dashboard with live stats
    ├── timeline_screen.dart     # Minute-by-minute day view
    ├── insights_screen.dart     # Trends, patterns, weekly AI report
    └── settings_screen.dart     # API key, toggles, data management
```

---

## Key Technical Details

### Background Service
Uses `flutter_background_service` to run as an Android foreground service.
Collection schedule:
- App usage: every 5 minutes
- Location: every 10 minutes
- Steps: every 2 minutes
- Hourly: updates AI insight metadata

### Data Privacy
- ALL data is stored in local SQLite on your device
- Only data sent externally: Claude API calls for AI summaries
- You control when AI analysis happens (manual tap)

### Android UsageStats API
Requires special "Usage Access" permission (not a regular runtime permission).
User must manually enable it in Android Settings.

---

## Troubleshooting

**"No app usage data"** → Grant Usage Access permission in Android Settings

**"Location not tracking"** → Grant "Allow all the time" location permission

**"AI summary failed"** → Check API key in Settings, ensure internet connection

**Battery drain?** → The foreground service uses minimal battery.
The location tracking (every 10min) is the main consumer.
Reduce frequency in `background_service.dart` if needed.

---

## Customization

### Add more app name mappings
Edit `lib/services/usage_stats_service.dart` → `_appNames` map

### Change tracking frequency
Edit `lib/services/background_service.dart` → Timer.periodic durations

### Customize Claude's personality
Edit `lib/ai/claude_service.dart` → `systemPrompt` strings

### Add new event types
1. Add to `LifeEvent.displayTitle` and `displayIcon`
2. Add a new service in `lib/services/`
3. Register it in `background_service.dart`
