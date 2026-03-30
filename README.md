# BrewGuide

**Your coffee brewing companion.**

BrewGuide is an iOS app that walks you through 25+ brewing methods with step-by-step guidance, on-device AI recommendations, a brew journal, and bean inventory tracking — all in a clean, adaptive interface.

---

## Screenshots

<p align="left">
  <img src="Screenshots/Screenshot 2026-03-22 at 15.14.12.png" width="200"/>
  <img src="Screenshots/Screenshot 2026-03-22 at 15.14.19.png" width="200"/>
  <img src="Screenshots/Screenshot 2026-03-22 at 20.22.45.png" width="200"/>
</p>

---

## Features

### Brewing Guides
- **25+ methods** across every category: Pour Over (V60, Chemex, Kalita Wave), Immersion (French Press, AeroPress, Clever Dripper), Pressure (Espresso, Moka Pot), Cold Brew (Nitro, Kyoto Tower), and Stovetop/Traditional (Turkish, Vietnamese Phin, South Indian Filter, Siphon)
- **Step-by-step timer** with a live brew ring, segmented progress bar, and per-step water callouts
- **Technique deep dives** covering origin stories, creator background, tasting notes, common mistakes, and curated YouTube tutorials

### Bean First (On-Device AI)
- Scan a coffee bag label with your camera — OCR extracts origin, process, roast level, and flavour notes
- On-device AI (Apple FoundationModels) matches the bean to the best brewing techniques with scored recommendations
- No data ever leaves your device

### Daily Suggestion
- A rotating daily brew recommendation with deep-dive content and a featured technique

### Brew Journal
- Log every brew session with ratings, notes, and parameters
- Persisted in Core Data, fully browsable and filterable

### Bean Inventory
- Track your beans by weight with animated progress rings
- Add, edit, or remove beans and link them to journal entries

### Live Activity & Dynamic Island
- Active brew sessions surface as a Live Activity on the Lock Screen and in the Dynamic Island with real-time step and timer updates

### Personalisation
- Appearance: System / Light / Dark
- Units: Celsius ↔ Fahrenheit, mL ↔ fl oz
- Auto-advance steps, haptic feedback toggle
- Favourites and recents across techniques

### Localisation
Content (methods, techniques, steps, beans, grind sizes) ships in **English, German, French, and Japanese**, loaded dynamically from locale-specific JSON files.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5 |
| UI | SwiftUI |
| Persistence | Core Data |
| On-Device AI | Apple FoundationModels |
| Widgets | WidgetKit + ActivityKit |
| Minimum iOS | iOS 17+ |
| Architecture | MVVM |

---

## Project Structure

```
BrewGuide-iOS-App/
├── Coffeebrew.xcodeproj/
├── Coffeebrew/
│   ├── App/                        # Entry point, environment
│   ├── Models/                     # BrewMethod, Technique, Bean, BrewStep, GrindSize
│   ├── Views/
│   │   ├── BeanFirst/              # Camera scan + AI recommendation flow
│   │   ├── BeanInventory/          # Bean stock management
│   │   ├── BrewGuide/              # Timer, step UI, pour bar
│   │   ├── Journal/                # Brew log + session detail
│   │   └── Components/             # Reusable cards, deep-dive sections
│   ├── ViewModels/                 # One ViewModel per feature
│   ├── Services/                   # DatabaseService, AIRecommendationService,
│   │                               # BrewTimerService, BrewLiveActivityService
│   ├── Utils/                      # Constants, Extensions, HapticsManager
│   └── Resources/
│       ├── *.json                  # Brewing data (+ _de, _fr, _ja variants)
│       └── Assets.xcassets/
├── BrewGuideWidgetExtension/       # Live Activity + Dynamic Island widget
├── CoffeebrewTests/
├── CoffeebrewUITests/
├── scripts/                        # Build scripts
├── Screenshots/
├── Prompts/                        # AI prompt files used in development
└── Docs/
    ├── Specs/                      # Project specification & feature docs
    ├── Design/                     # UI mockups and visual references
    ├── Data/                       # Coffee brewing database (source data)
    └── Assets/                     # Reference icons and technique images
```

---

## Getting Started

### Requirements

- Xcode 16+
- iOS 17+ device or simulator
- macOS Sequoia or later (for FoundationModels on-device AI)

### Running the App

1. Clone the repo:
   ```bash
   git clone https://github.com/azizrehhmann/BrewGuide-iOS-App.git
   cd BrewGuide-iOS-App
   ```

2. Open the project in Xcode:
   ```bash
   open Coffeebrew.xcodeproj
   ```

3. Select a simulator or connected device and press **Run** (`⌘R`).

> **Note:** The Bean First AI scanning feature requires a physical device with Apple Intelligence support. It will gracefully degrade on unsupported hardware.

---

## Deep Links

| URL | Action |
|---|---|
| `brewguide://brew/resume` | Resume an active brew session |
| `brewguide://suggestion` | Open the daily suggestion |

---

## Localisation

To add a new language, duplicate each of the following JSON files in `Coffeebrew/Resources/` with a locale suffix (e.g. `_es` for Spanish):

```
methods_es.json
techniques_es.json
steps_es.json
beans_es.json
grind_sizes_es.json
```

`DatabaseService` picks up the correct file automatically based on the device locale, with a fallback to English.

---

## Roadmap

See [`Docs/Specs/brewguide_feature_roadmap.svg`](Docs/Specs/brewguide_feature_roadmap.svg) for the full visual roadmap.

---

## License

This project is private. All rights reserved.
