# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Open in Xcode
open Coffeebrew.xcodeproj

# Build (CLI)
xcodebuild -project Coffeebrew.xcodeproj -scheme Coffeebrew -configuration Debug build

# Run all unit tests
xcodebuild test -project Coffeebrew.xcodeproj -scheme Coffeebrew -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class
xcodebuild test -project Coffeebrew.xcodeproj -scheme Coffeebrew -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CoffeebrewTests/BrewTimerServiceTests

# Convert Excel coffee data to JSON
python3 scripts/excel_to_json.py <path/to/excel>
```

No external dependency managers — no CocoaPods, SPM packages, or Fastlane.

## Architecture

**MVVM + SwiftUI**, targeting iOS 17+. No third-party libraries.

### Core Data Flow

```
AppEntry.swift
  └─ AppEnvironment (ObservableObject, created once in AppEntry)
       ├─ DatabaseService  ← loads JSON from Resources/Data/ with locale fallback
       └─ Navigation state (selectedMethod, selectedTechnique, selectedBean)

Views → ViewModels (ObservableObject, one per feature)
  └─ Services (business logic, Core Data, ActivityKit, FoundationModels)
```

### Key Layers

**App bootstrap** (`Coffeebrew/App/`): `AppEntry.swift` handles deep links (`brewguide://brew/resume`, `brewguide://suggestion`) and injects `AppEnvironment`, `ManagedObjectContext`, locale, and color scheme into the environment.

**AppEnvironment** centralizes all user preferences (`@AppStorage`) — units (°C/°F, mL/fl oz), appearance, haptics, auto-advance — plus navigation selection state.

**DatabaseService** loads the five JSON datasets (methods, techniques, steps, beans, grind_sizes) from `Resources/Data/`. Locale-specific files (e.g. `techniques_ja.json`) are tried first, with English as fallback. Call `reload(languageCode:)` when the user changes language in AppEnvironment.

**Core Data** (`BrewGuide.xcdatamodeld`) has two entities — `BrewSession` and `CoffeeBean` — both synced via CloudKit (`iCloud.Aziz.Coffeebrew`). `PersistenceController` gracefully falls back to local SQLite when CloudKit is unavailable.

**BrewTimerService** manages per-step countdowns (configured via `configureStep()`) and total elapsed time. It is timer-only; `BrewGuideView` pushes step state to `BrewLiveActivityService`.

**AIRecommendationService** uses Apple's `FoundationModels` framework (on-device LLM) for two tasks: parsing scanned bag-label text into `ScannedBeanData`, and scoring techniques for a given bean profile.

**BrewLiveActivityService** wraps `ActivityKit` to start/update/end a Live Activity and Dynamic Island widget during an active brew session. The widget extension lives in `BrewGuideWidgetExtension/`.

### Brew Session Flow

1. Method → Technique → Beans selection (ViewModels configure from DatabaseService)
2. `BrewSessionViewModel` initialized with ordered `BrewStep` array
3. `BrewTimerService` drives per-step countdown; `BrewLiveActivityService` reflects state on Lock Screen
4. On completion, `BrewJournalViewModel` persists a `BrewSession` to Core Data (CloudKit synced)

### Bean First (AI) Flow

1. `BeanScannerService` captures image via camera or photo library
2. Vision OCR extracts text → `AIRecommendationService.parseScannedText()` → structured `ScannedBeanData`
3. `AIRecommendationService.recommendTechniques()` scores all techniques and returns ranked results with AI reasoning

## Localization

Supported: `en`, `de`, `fr`, `ja`. JSON files in `Coffeebrew/Resources/Data/` follow the pattern `{resource}_{languageCode}.json`. `AppEnvironment.preferredLanguage` (@AppStorage) triggers `DatabaseService.reload()` on change.

## Entitlements & Capabilities

- Apple Intelligence / FoundationModels (on-device AI)
- Sign in with Apple
- iCloud + CloudKit (`iCloud.Aziz.Coffeebrew`)
- Camera + Photo Library (bean bag scanning)
- Deep link URL scheme: `brewguide://`
