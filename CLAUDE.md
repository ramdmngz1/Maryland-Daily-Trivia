# CLAUDE.md — Maryland Daily Trivia

## Project Overview

Maryland Daily Trivia is a real-time competitive bar-trivia iOS and Android app where all users receive the same 10 Maryland-themed questions at synchronized times, competing on score and speed. The backend runs on Cloudflare Workers + D1 (SQLite).

This project is a direct port of Texas Daily Trivia, adapted for Maryland with:
- Maryland flag color scheme (Red #CC1433, Gold #C8A84B)
- Blue crab mascot (replaces armadillo)
- 210 Maryland trivia questions (5 categories: Culture, Food, Geography, History, Sports)

## Architecture

**iOS App** (`iOS/Maryland Daily Trivia/Maryland Daily Trivia/`): SwiftUI MVVM app targeting iOS 15+.
- Same architecture as Texas Daily Trivia
- Entry point: `Maryland_Daily_TriviaApp.swift`
- Mascot: `BlueCrabSpriteView` (typealias `ArmadilloSpriteView` provided for compatibility)
- Questions: `questions_md.json` (bundled)

**Android App** (`Android/Android/`): Kotlin/Jetpack Compose
- Package: `com.copanostudios.marylanddailytrivia`
- Mascot: `BlueCrabSprite` / `BlueCrabLogo` (backward-compat aliases provided)

**Backend** (`maryland-trivia-worker/`): Cloudflare Worker (JavaScript) with D1 database.
- Worker URL: `https://maryland-trivia-contest.f22682jcz6.workers.dev`
- D1 Database ID: `f3586d22-5426-4ada-bdec-5d245b63d34f`
- 210 Maryland questions loaded into D1

## Build & Run

### iOS
```bash
open "iOS/Maryland Daily Trivia/Maryland Daily Trivia.xcodeproj"
# Build: ⌘B  |  Run: ⌘R  |  Test: ⌘U
```

### Android
```bash
cd Android/Android
./gradlew assembleDebug
./gradlew installDebug
```

### Backend
```bash
cd maryland-trivia-worker
npm install
npm run dev           # Local dev at http://localhost:8787
npm run deploy        # Deploy to production
npm run tail          # Stream live logs
```

## Before First Build — Required Steps

### 1. AdMob IDs (iOS)
In `iOS/Maryland Daily Trivia/Maryland-Daily-Trivia-Info.plist`:
- Replace `REPLACE_WITH_MARYLAND_ADMOB_APP_ID` with real iOS AdMob App ID

In `iOS/Maryland Daily Trivia/Maryland Daily Trivia/AdMobConfig.swift`:
- Replace `REPLACE_WITH_MARYLAND_BANNER_AD_ID` with real banner ad unit ID
- Replace `REPLACE_WITH_MARYLAND_INTERSTITIAL_AD_ID` with real interstitial ad unit ID

### 2. AdMob IDs (Android)
In `Android/Android/gradle.properties` (or `local.properties`), add:
```
ADMOB_ANDROID_APP_ID=ca-app-pub-XXXX~XXXX
ADMOB_ANDROID_BANNER_ID=ca-app-pub-XXXX/XXXX
```

### 3. Xcode Project Settings
Open the project in Xcode and confirm:
- Bundle ID: `com.copanostudios.marylanddailytrivia`
- Product Name: `Maryland Daily Trivia`
- Signing team is set

### 4. Blue Crab Sprite Assets (iOS + Android)
Add the blue crab animation frames as image assets:
- **iOS**: Add to `Assets.xcassets` — names: `crab_walk_01` … `crab_walk_08`, `crab_icon`, `crab_logo`
- **Android**: Add to `res/drawable/` — names: `crab_walk_01.png` … `crab_walk_08.png`, `crab_logo.png`

The app falls back to `crab_icon`/`crab_logo` static images if walk frames are missing.

### 5. App Store Connect / Google Play
- Register new app in App Store Connect with bundle ID `com.copanostudios.marylanddailytrivia`
- Register new app in Google Play Console with package `com.copanostudios.marylanddailytrivia`

## API Endpoints

Base: `https://maryland-trivia-contest.f22682jcz6.workers.dev`

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/live-state` | GET | Real-time game state (primary polling endpoint) |
| `/api/rounds/current` | GET | Current active round |
| `/api/rounds/{roundId}/score` | POST | Submit score, returns rank |
| `/api/leaderboard/{roundId}` | GET | Top 100 leaderboard |
| `/api/leaderboard/daily` | GET | Top 10 in last 24h |
| `/api/user/{userId}/stats` | GET | User statistics |
| `/api/questions` | POST | Fetch questions by IDs (auth required) |
| `/health` | GET | Health check |

## Timing & Scoring

- 12s per question, 10s explanation, 10 questions per round
- Round cycle: 250 seconds (~4 min 10s)
- Base points: Easy=600, Medium=800, Hard=1000
- Speed bonus: up to 400 additional points

## Color Palette

| Token | Value | Notes |
|---|---|---|
| `primary` / `accent` | `#CC1433` | Maryland Red (Crossland arms) |
| `secondary` | `#C8A84B` | Maryland Gold (Calvert arms) |
| `neon` | `#FFD700` | Bright gold glow |
| `darkBg` | `#0D0305` | Near-black with red undertone |
| `cardBg` | `#1F0A0D` | Dark maroon |
| `textPrimary` | `#F7EDE5` | Warm cream |

## Question Bank

- 210 questions in `Questions/questions_md.json`
- Categories: Culture (43), Food (40), Geography (44), History (42), Sports (41)
- Difficulties: Easy (78), Medium (64), Hard (68)
- All loaded into D1 at database creation

## Websites

- Privacy: `https://www.copanostudios.com/privacy-maryland-daily-trivia`
- Support: `https://www.copanostudios.com/support-maryland-daily-trivia`
