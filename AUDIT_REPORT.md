# BrewGuide — Code Audit Report

## Context

Full top-to-bottom audit requested across Sections 1–10 (build config, JSON data, models,
services, view models, views, accessibility, dark mode, tests, performance). **Nothing was
fixed** — this is report-only, as instructed.

Inspected: 85 Swift files, 20 JSON data files (en/de/fr/ja), `project.pbxproj`, entitlements,
both Info.plists, the Core Data model, the asset catalog, the string catalog, the test target
and the widget extension. Every finding below was verified against the actual source; claims
that did not survive checking are listed under "Checked and cleared" so they don't get re-raised.

No source files were changed in producing this report.

---

## Summary

- 🔴 Critical: 6
- 🟠 High: 24
- 🟡 Medium: 41
- 🔵 Low: 28
- ⚪ Info: 9

---

## Critical issues

### `Coffeebrew.xcodeproj/project.pbxproj` — no target sets `CODE_SIGN_ENTITLEMENTS`
**Issue:** `Coffeebrew/Coffeebrew.entitlements` declares Apple Intelligence, Sign in with Apple,
CloudKit/iCloud and ubiquity KV store, but `CODE_SIGN_ENTITLEMENTS` appears nowhere in the
project file (verified by grep across all four `XCBuildConfiguration` blocks). The file is never
applied to a build.
**Impact:** Every entitled capability the app is written against fails at runtime — Foundation
Models (`AIRecommendationService`), Sign in with Apple (`ProfileView`), and iCloud sync
(`PersistenceController`). The three headline features are dead in any signed build.
**Fix:** Add `CODE_SIGN_ENTITLEMENTS = Coffeebrew/Coffeebrew.entitlements;` to both the Debug and
Release configurations of the Coffeebrew target.

### `Coffeebrew/App/AppEnvironment.swift:17-27` — `@AppStorage` used inside an `ObservableObject`
**Issue:** Ten user preferences are declared `@AppStorage` inside a plain `ObservableObject`.
`@AppStorage` is a `DynamicProperty`; it only publishes when installed in a `View`. Inside a class
it reads and writes `UserDefaults` correctly but never fires `objectWillChange`.
**Impact:** The widest-reaching defect in the app.
- `AppEntry.swift:11` `if appEnvironment.hasSeenOnboarding` never re-evaluates → **finishing
  onboarding does not advance to Home until the app is relaunched.**
- `AppEntry.swift:32` `.onChange(of: appEnvironment.preferredLanguage)` never fires, and the
  `didSet { applyLanguage() }` at line 26 is bypassed when Settings writes through the projected
  binding (`SettingsView.swift:136`) → **de/fr/ja is unreachable from the language picker.**
- All nine Settings toggles/steppers (`SettingsView.swift:117-232`) bind `$appEnvironment.*` and
  none propagates to already-open views.
- `SettingsView.swift:238` "Replay onboarding" sets the flag but never navigates.
**Fix:** Replace with `@Published` properties backed by explicit `UserDefaults` reads/writes
(or a `didSet` that persists), so mutations publish. Keep the same key names to preserve
existing user data.

### `Coffeebrew/Resources/Data/steps.json` (rows 107–113, all four locales) — orphaned duplicate recipe with colliding IDs
**Issue:** Seven rows are a stray copy of the *AeroPress Standard/Upright* recipe, mis-tagged
`technique_id = "aeropress-wac-2024-winner-george-stanica"` and carrying `step_id`s
`aeropress-wac-2024-winner-george-stanica-step-1` … `-step-7`, which collide exactly with that
technique's real steps. `step_number` for the technique runs `[1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,9,10]`.
**Impact:** The WAC-2024 technique shows **17 steps instead of 10**, with two different recipes
interleaved. `BrewStep.id` is `stepId` (`BrewStep.swift:13`), so `ForEach` receives duplicate
identifiers — undefined row rendering and broken animations. Step water sums to **216 ml against
a 108 ml recipe**, so the pour targets are double. `Dictionary(grouping:)` + non-stable `sorted`
(`DatabaseService.swift:105`) means the interleaving order can differ between runs.
**Fix:** Delete rows 107–113 from `steps.json`, `steps_de.json`, `steps_fr.json`, `steps_ja.json`.
The upright recipe already exists correctly at rows 296–302 under `aeropress-standardupright`.

### `BrewGuideWidgetExtension/` — three unguarded traps crash the widget process
**Issue:** Three separate invalid-input paths, all reachable when `totalSteps == 0`:
- `BrewLiveActivityWidget.swift:40` — `ForEach(1...min(context.attributes.totalSteps, 7))` traps
  on `1...0` ("Range requires lowerBound <= upperBound").
- `BrewDynamicIslandViews.swift:79` and `BrewLockScreenView.swift:22` — unguarded
  `Double(state.currentStep) / Double(attrs.totalSteps)`; `0/0` is `NaN`, and
  `Circle().trim(to: .nan)` is an invalid CoreGraphics path.
- `BrewDynamicIslandViews.swift:28,121` and `BrewLockScreenView.swift:76` —
  `Text(timerInterval: Date()...endTime)` traps whenever `endTime` is already in the past
  (stale activity, restored activity, clock skew).
**Impact:** The Live Activity crashes on the Lock Screen and in the Dynamic Island. It is
reachable in normal use: `BrewGuideView.swift:115` attaches `.onAppear` to the *outer* `Group`,
so `startLiveActivityIfNeeded()` runs even on the `steps.isEmpty` branch (line 88) and passes
`totalSteps: steps.count == 0` (line 529). A single JSON decode failure puts every technique in
that state.
**Fix:** Guard `totalSteps > 0` before the `ForEach` and before every division; clamp the timer
range with `max(endTime, Date().addingTimeInterval(1))`; and return early from
`startLiveActivityIfNeeded()` when `steps.isEmpty`.

### `Coffeebrew/Views/BrewGuideView.swift:436-437, 495-498` — post-brew rating sheet is unreachable
**Issue:** `advanceStep()` sets `showComplete = true`, which immediately pushes `BrewCompleteView`
via `.navigationDestination(isPresented:)` (line 101). 500 ms later, a `Task` sets
`showPostBrewRating = true` — a `.sheet` attached to `BrewGuideView` (line 104), which is no
longer the visible view. `BrewCompleteView` sets `.navigationBarBackButtonHidden(true)`
(`BrewCompleteView.swift:79`), so the user cannot get back to it.
**Impact:** `PostBrewRatingView` never presents. Every rating, flavour tag and tasting note the
feature exists to capture is silently discarded. The hardcoded `Task.sleep` is also a race.
**Fix:** Present the rating sheet from `BrewCompleteView` instead, or show it *before* pushing
completion. Remove the sleep-based sequencing.

### `Coffeebrew/Views/BrewGuideView.swift:480-483` — journal saves the wrong bean and serving size
**Issue:** Two independent data defects in one call:
- `beanName`/`beanOrigin`/`roastLevel` read `appEnvironment.selectedBean`, which is **never
  assigned anywhere in the codebase** — verified by grep, it is only declared
  (`AppEnvironment.swift:12`) and nilled in `reset()` (line 56). The user's actual pick lives in
  `BeansViewModel.selectedBean` and is handed to `ParametersView` as a `let` that never propagates.
- `servingSize:` records `appEnvironment.defaultServings` (the Settings default), not the
  `servings` the user chose in `ParametersView`.
**Impact:** Every journal entry ever written records a nil bean, and a serving size that
contradicts its own coffee/water amounts — brew 4 cups with a default of 1 and the entry says
"1 cup, 60 g coffee". The journal's bean history and per-serving stats are permanently wrong.
**Fix:** Thread the selected `Bean` and the chosen `servings` from `ParametersView` through to
`BrewGuideView` (or assign them onto `AppEnvironment` at selection time) and read them here.

---

## High issues

### `Coffeebrew/BrewGuide.xcdatamodeld/.../contents:6,11,25,33` — model is CloudKit-incompatible
**Issue:** `PersistenceController.swift:41` uses `NSPersistentCloudKitContainer`, but
`BrewSession.id`, `BrewSession.brewedAt`, `CoffeeBean.id` and `CoffeeBean.purchaseDate` are
non-optional with no default value. CloudKit requires every attribute to be optional or defaulted.
**Impact:** `loadPersistentStores` fails, and lines 71–92 silently fall back to a local-only
store. iCloud sync can never work, the entitlements and the sync UI both imply it does, and the
user is never told.
**Fix:** Mark those four attributes optional (or give them defaults) and surface the load error
instead of swallowing it.

### `Coffeebrew/ViewModels/BrewSessionViewModel.swift` — entire class is dead code
**Issue:** Verified by grep: referenced nowhere outside its own declaration and
`CoffeebrewTests/ViewModelTests.swift`. The shipping brew flow is implemented inline in
`BrewGuideView.swift`.
**Impact:** Nine unit tests validate a code path the app never executes, giving false confidence
about exactly the logic the brief asks about (step bounds, serving size, cumulative water). The
real implementation has zero coverage.
**Fix:** Either adopt the view model in `BrewGuideView` or delete it and retarget the tests at
the shipping logic.

### `Coffeebrew/Views/BrewGuideView.swift:457-463` — timer auto-start condition is provably dead
**Issue:** `configureStep` calls `pause()` as its first statement (`BrewTimerService.swift:41`),
so `timer.isRunning` is always `false` at line 460. The condition
`if timer.isRunning || (currentStepIndex > 0)` degenerates to `currentStepIndex > 0`.
**Impact:** Step 1's timer never auto-starts while every later step does; and pressing
**Previous** (line 453) silently restarts a countdown the user was trying to review. Because
`totalElapsedSeconds` only accrues while running, step 1's duration is missing from every saved
brew time.
**Fix:** Decide the intent explicitly — track whether the timer was running *before*
`configureStep`, and don't auto-start on backward navigation.

### `Coffeebrew/Views/BrewGuideView.swift:126-130` — leaving the brew screen never stops the timer
**Issue:** `.onDisappear` only ends the Live Activity. It never calls `timer.pause()` or
`reset()`, and `BrewTimerService` has no `deinit { timer?.cancel() }`.
**Impact:** Swiping back mid-brew leaves a `RunLoop.common` timer firing every second for the
process lifetime — one per brew screen visited. Battery drain and a growing set of live timers.
**Fix:** Pause/reset in `.onDisappear` and add a `deinit` that cancels the subscription.

### Deep links are write-only — `AppEnvironment.swift:8-9`, `AppEntry.swift:17-24`
**Issue:** `shouldShowActiveBrew` and `shouldShowDailySuggestion` are declared and written but
**never read by any view** (verified by grep across the repo).
**Impact:** Tapping the Live Activity (`.widgetURL("brewguide://brew/resume")`,
`BrewLiveActivityWidget.swift:71`) opens the app to Home and does nothing else. Same for the
daily notification. Both advertised entry points are inert.
**Fix:** Observe both flags in `HomeView` and drive the corresponding navigation.

### `Coffeebrew/Services/DailySuggestionService.swift:167` — no notification delegate exists
**Issue:** `content.userInfo = ["url": "brewguide://suggestion"]`, but there is **no
`UNUserNotificationCenterDelegate` anywhere in the repo** (verified by grep). A `userInfo`
payload does not open a URL by itself.
**Impact:** The daily-suggestion notification can never route anywhere, compounding the finding
above.
**Fix:** Add a delegate implementing `userNotificationCenter(_:didReceive:)` that parses
`userInfo["url"]` and forwards it, and register it at launch.

### `Coffeebrew/Services/DailySuggestionService.swift:159-177` — repeating notification is frozen
**Issue:** `content.title`/`body` are built from *today's* suggestion, but the trigger is
`repeats: true` with a fixed identifier and nothing re-schedules it after `recompute`.
**Impact:** Every subsequent morning the user is told to brew whatever was suggested on the day
they enabled the toggle.
**Fix:** Re-schedule on each recompute, or make the notification generic and resolve the
suggestion when it is tapped.

### `Coffeebrew/Services/DailySuggestionService.swift:389-397` — difficulty matching is inert
**Issue:** The lookup uses `databaseService.method(byName: record.methodName)`, but
`BrewGuideView.swift:472` writes the **category** into `methodName` ("Pour Over") while
`methodByName` is keyed on method names ("V60 Pour Over").
**Impact:** The lookup always fails, `difficultyCount` is always empty, and line 396 always
falls through to `?? 3`. The entire "+30 difficulty match" scoring rule (lines 231-233) is dead,
so daily suggestions ignore the user's demonstrated skill level.
**Fix:** Use `record.equipmentName` (as `fetchYesterdayCategory` correctly does at line 377).

### `Coffeebrew/App/AppEnvironment.swift:41-43` — saved language is never applied at launch
**Issue:** `applyLanguageOnLaunch()`'s only call site is `AppEntry.swift:33`, inside
`.onChange(of:)`. Nothing calls it during launch.
**Impact:** On a cold start `DatabaseService.init` loads the **device** locale
(`DatabaseService.swift:37`) and `resolvedLocale` stays `Locale.current`. A user who chose French
on an English device gets English content every launch. (Compounded by the `@AppStorage` defect
above, which also stops the `.onChange` from ever firing.)
**Fix:** Call `applyLanguageOnLaunch()` from `AppEnvironment.init` or an app-launch task.

### `Coffeebrew/Localizable.xcstrings` — 62 untranslated keys, all with format specifiers
**Issue:** 379 keys total; de/fr/ja each cover 317. The 62 missing are exactly those containing
`%@` / `%lld` — "Step %lld of %lld", "Day %lld of %lld", "Total brew time: %@",
"Your %@ is ready to enjoy.", "%lld°C", plus most VoiceOver labels.
**Impact:** In German, French and Japanese every interpolated string and most accessibility
labels render in English, in the middle of otherwise translated screens.
**Fix:** Translate the 62 keys. Also note `Extensions.swift:80-96` returns hardcoded English
`"min"`/`"s"`, and `DailySuggestionCardView.swift:178-182` uses a `DateFormatter` with a
hardcoded `"EEE d MMM"` pattern and no locale.

### `Coffeebrew/Services/AIRecommendationService.swift:51` — `DatabaseService()` constructed inside a loop
**Issue:** `let method = DatabaseService().method(byId: t.methodId)` sits inside a `.map` over all
techniques. Each construction runs `loadAll()`, decoding five JSON files (~173 KB).
**Impact:** ~37 full reloads per recommendation — roughly 185 file reads and ~6.4 MB of JSON
decoding for what should be 37 dictionary hits. Multi-second stall on the app's headline feature.
**Fix:** Pass the shared `databaseService` in; `BeanFirstViewModel` already holds it (line 44).

### `Coffeebrew/Services/DatabaseService.swift:29-31` — all JSON decoded synchronously on the main thread
**Issue:** `init()` calls `loadAll()`, reached from `AppEnvironment`'s default argument, which is
the `@StateObject` in `AppEntry.swift:6`. `AppEntry.swift:7` additionally forces the full Core
Data + CloudKit store load (and `initializeCloudKitSchema` in DEBUG).
**Impact:** Two blocking I/O subsystems on the launch path before the first frame.
**Fix:** Load off the main thread behind an async entry point, or at minimum defer the Core Data
schema work.

### `Coffeebrew/Services/DatabaseService.swift:72-89` — decode failures silently become empty arrays
**Issue:** Both `catch` blocks `print` and `return []`, and `isLoaded = true` is set regardless
(line 56).
**Impact:** A malformed `steps.json` yields zero steps for every technique with no error surface,
no retry, and no recovery. This is also the trigger for the widget crashes above.
**Fix:** Propagate a load-failure state and surface it in the UI.

### `Coffeebrew/Views/HomeView.swift:249-256` — "quick re-brew" routes to the wrong screen
**Issue:** The closure is functionally identical to `onSelectTechnique` above it (it just adds a
haptic), despite a comment promising it navigates to `ParametersView`.
**Impact:** Quick re-brew drops the user on `BeansView` and re-asks every question.
`lastCoffeeGrams` / `lastWaterMl` / `lastServingSize`, populated in
`FavouritesRecentsViewModel.swift:81-83`, are never consumed. The feature does not do what it says.
**Fix:** Route to `ParametersView` pre-populated from the stored last-brew values.

### `Coffeebrew/Views/Journal/RatingStarsView.swift:16-24` — ratings are unreachable via VoiceOver
**Issue:** Stars use bare `.onTapGesture` on `Image`s (no `.isButton` trait, no per-star label),
and `.accessibilityElement(children: .combine)` collapses the row into one non-actionable element
with no `accessibilityAdjustableAction`.
**Impact:** A VoiceOver user cannot rate a brew at all, in `PostBrewRatingView` or
`BrewSessionDetailView`. Hit targets are also 36 pt and 11 pt, below the 44 pt minimum that
`Constants.Layout.minTouchTarget` already defines.
**Fix:** Make each star a `Button` with a label like "3 stars", or expose an
`accessibilityAdjustableAction` on the combined element.

### `Coffeebrew/Utils/FlowLayout.swift:30-31` — oversized chips never wrap
**Issue:** Subviews are measured with `.unspecified`, and the wrap guard requires `currentX > 0`,
so a chip wider than the container is never wrapped or compressed.
**Impact:** At accessibility Dynamic Type sizes a single long flavour pill overflows on all eight
screens using `FlowLayout` (`PostBrewRatingView:86`, `BeanConfirmView:111`, `BeanDetailView:226`,
`AddEditBeanSheet:186,237`, `BeansView:227`, `BeanRecommendationsView:87`,
`BrewSessionDetailView:138`).
**Fix:** Propose `ProposedViewSize(width: maxWidth, height: nil)` when measuring, and clamp the
returned width to `maxWidth` (line 42).

### `Coffeebrew/Views/Components/YouTubePlayerView.swift:19-38` — HTML reloaded on every update
**Issue:** `updateUIView` calls `loadHTMLString` unconditionally.
**Impact:** Any parent state change — the expand spring animation frames, a colour-scheme change,
a Dynamic Type change — reloads the iframe and restarts the video from zero. Combined with
`mediaTypesRequiringUserActionForPlayback = []` (line 10), audio restarts unexpectedly.
**Fix:** Build the HTML once in `makeUIView`; in `updateUIView` reload only when `youtubeId`
changes. Add `dismantleUIView` to stop playback. Also pass
`baseURL: URL(string: "https://www.youtube.com")` — a nil base URL gives the document a null
origin, which YouTube's embed player commonly refuses.

### `Coffeebrew/Views/BeanFirst/BeanScannerView.swift:120,127` — image picker can only be opened once
**Issue:** `ImagePickerView.Coordinator` dismisses the UIKit controller directly without setting
the `showCamera`/`showPhotoPicker` binding back to `false`. Same pattern at
`BeanInventoryView.swift:158-168`.
**Impact:** The binding stays `true`, so the sheet cannot present again — tapping "Take Photo" a
second time does nothing.
**Fix:** Set the binding to `false` in both delegate callbacks instead of calling `dismiss` on the
picker.

### `Coffeebrew/Views/BeanFirst/BeanScannerView.swift:31-33` — camera used without availability or permission check
**Issue:** `sourceType: .camera` with no `UIImagePickerController.isSourceTypeAvailable(.camera)`
and no `AVCaptureDevice.authorizationStatus` check. Same at `BeanInventoryView.swift:107-111`.
**Impact:** Black sheet or crash on camera-less devices and on first denial.
**Fix:** Check availability and authorization, and fall back to the photo library.

### `Coffeebrew/ViewModels/BrewJournalViewModel.swift` — list state diverges from the store
**Issue:** `fetchSessions()` is called from `init` and (conditionally) `toggleFavourite`, but
**not** from `saveSession`, `updateRating`, `updateNotes`, `updateFlavourTags`, `delete` or
`deleteAll`. `saveSession` instead does `sessions.insert(session, at: 0)` (line 105), ignoring
both the active sort order and the active predicate.
**Impact:** A new brew appears at the top even under "oldest first" or "highest rated", and
appears at all even when a favourites/rating filter should exclude it. Rating a visible session
below the active filter threshold leaves it in the list.
**Fix:** Call `fetchSessions()` after every mutation, or re-apply sort/predicate on insert.

### `Coffeebrew/ViewModels/BrewJournalViewModel.swift:151-155` — `deleteAll()` does not delete all
**Issue:** It iterates `sessions`, which is the *filtered* result set.
**Impact:** With any filter active, "delete everything" silently leaves the unfiltered rows in
the store — they reappear when the filter clears. Destructive action with a misleading name.
**Fix:** Use an `NSBatchDeleteRequest` or fetch unfiltered before deleting.

### `Coffeebrew/Assets.xcassets/AccentColor.colorset/Contents.json` — colorset is empty
**Issue:** `"colors": [{"idiom": "universal"}]` — no components, no dark variant. It is the global
accent for both app and widget (`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`).
**Impact:** All system tinting falls back to default blue against a gold design system. It is also
the only colorset in the catalog lacking a dark variant; the other five are correct.
**Fix:** Give it light and dark components matching `Accent`, or point the build setting at
`Accent`.

### White-on-gold contrast fails WCAG in both appearances — ~25 sites
**Issue:** `Accent` is `(0.725, 0.529, 0.259)` light / `(0.816, 0.635, 0.369)` dark. White text on
it measures ≈3.2:1 light and ≈2.3:1 dark — the dark value fails even the 3:1 large-text threshold.
**Impact:** Primary CTAs are hard to read, worst in dark mode. Sites include
`BeansView:100`, `ParametersView:90,379`, `OnboardingView:86`, `BrewCompleteView:60`,
`DailySuggestionCardView:70`, `HomeView:150`, `SettingsView:57`, `ProfileView:65`,
`ChipViews:25,47`, `BeanConfirmView:53,87,167`, and others.
**Fix:** Darken the gold for text backgrounds, or switch the foreground to
`Constants.Colors.primaryColor` on gold fills.

### `Coffeebrew/Views/BrewGuide/BrewTimerRing.swift` — timer is invisible to VoiceOver
**Issue:** The file contains no accessibility modifiers at all; the countdown at lines 40-48 is
two loose `Text` views with no `accessibilityValue` and no `.updatesFrequently` trait.
**Impact:** VoiceOver never announces remaining time — the core brewing feedback is unavailable.
**Fix:** Combine into one element with an `accessibilityValue` of the remaining time and add
`.accessibilityAddTraits(.updatesFrequently)`.

### `Coffeebrew/Views/BrewGuide/SegmentedProgressBar.swift:32` and `WaterCalloutView.swift:81` — accessibility labels attached to nothing
**Issue:** `SegmentedProgressBar` puts `.accessibilityLabel("Step \(currentStep) of
\(totalSteps)")` on an `HStack` of `Capsule`s, which generate no accessibility elements — so
nothing carries the label. `WaterCalloutView`'s root `.combine` swallows the unit-toggle Button
at lines 33-45, destroying its own label.
**Impact:** "Step 3 of 7" is never announced, and the ml↔fl oz toggle is unreachable.
**Fix:** Add `.accessibilityElement(children: .ignore)` before the label on the progress bar;
exclude the button from the combine on the callout.

### `Coffeebrew/Views/BeanInventory/BeanProgressRing.swift:35` — font size derived from ring diameter
**Issue:** `.font(.system(size: ringSize * 0.2, ...))` inside a hard
`.frame(width: ringSize, height: ringSize)`.
**Impact:** Ignores Dynamic Type entirely. At `ringSize: 32` (`HomeView.swift:516`) the text is
**6.4 pt**; at 52–60 pt rings it is still ~10 pt. Unreadable, and unresponsive to accessibility
text settings.
**Fix:** Use a scalable text style with `minimumScaleFactor`, and let the frame grow.

---

## Medium issues

**Data**

- `techniques*.json` — `aeropress-standardupright` declares `"step_count": 0` while 7 steps exist
  (all four locales). Any `1...stepCount` range traps and any `x / stepCount` yields NaN. Every
  other technique matches. *Fix: set to 7.*
- `techniques*.json` — `total_time_seconds` disagrees with the sum of step durations in **35 of
  37** techniques, from −390 s to +86 400 s. Displayed brew times are unreliable.
  *Fix: recompute, or document it as wall-clock including untimed steps.*
- **Seven techniques have every step at `duration_seconds = 0`** — Cold Brew, Moka Pot, Drip
  Machine, South Indian Filter, Kyoto Slow Drip, Single Serve Pod, Nitro Cold Brew. The timer
  never runs and auto-advance never fires for any of them. *Fix: set real durations for the steps
  that involve waiting.*
- `techniques*.json` — `water_temp_c` of `0` for Kyoto Slow Drip renders as "0°C"/"32°F" in the UI.
  Cold Brew and Nitro at `2` are defensible; Turkish Competition at `60` is suspicious for a
  method that boils. *Fix: review; use a nullable field for cold methods.*
- 8 steps state a duration in the instruction that `duration_seconds` contradicts (table below).
- All 303 steps have `image_name: null`, all 74 beans `notes: null`, all 24 methods
  `image_name: null` — while **17 `method_*` imagesets ship unused** in the asset catalog.

**Services**

- `DatabaseService.swift:95,97,100,113` — `Dictionary(uniqueKeysWithValues:)` traps on duplicate
  keys. I verified all four keys are duplicate-free in all four locales today, so it does not
  crash now — but `methodByName` keys on a *translated display name*, one edit from a launch
  crash, and `steps.json` already ships duplicate IDs. *Fix: `Dictionary(_:uniquingKeysWith:)`.*
- `DatabaseService.swift:105,110,121-125` — `sorted` is not stable and `allTechniquesWithMethod`
  uses raw `String.<` rather than `localizedStandardCompare`, so localized lists sort wrongly.
- `DatabaseService.swift:41-45` — `reload` rewrites shared state with no synchronization and no
  change notification; views hold no subscription so they never refresh.
- `DatabaseService.swift:36,56` — `isLoaded` latches `true` even when every array came back empty.
- `BrewTimerService.swift:49-53` — `start()` clears `stepCompleted`, so pause-then-play on a
  finished step re-fires completion: duplicate haptic, duplicate burst, second auto-advance.
- `BrewTimerService.swift:40-47` — with `duration == 0`, `tick()`'s `stepDurationSeconds > 0`
  guard means `stepCompleted` never becomes true, so **auto-advance silently never works for the
  227 of 303 steps with zero duration**, while `BrewGuideView:460` still starts a timer for them.
- `BrewLiveActivityService.swift:31-34` — comment says "synchronously" but the loop spawns
  `Task`s; `Activity.request` runs before they finish, which is exactly what makes `request` throw.
- `BrewLiveActivityService.swift:12,130` — `currentActivity` is written from a detached `Task` and
  read from the main thread on a non-`Sendable` singleton; it is also nilled asynchronously, so an
  `updateStep` right after `endActivity` finds an already-ended activity.
- `BrewLiveActivityService.swift:125` — `endActivity` early-returns when `currentActivity` is nil,
  so an activity orphaned by an app kill can never be ended. *Fix: iterate
  `Activity<BrewActivityAttributes>.activities`.*
- `BrewLiveActivityService.swift:150-153` — `pausedSecondsRemaining` is overloaded; when a running
  timer reaches 0 the lock-screen countdown jumps back to the full step duration.
- `AIRecommendationService.swift:24-28` — no validation of model output: empty arrays, wrong
  counts, duplicate ranks and hallucinated `techniqueId`s are all accepted, and unknown IDs are
  silently dropped, so the user can reach a results screen with zero results and no error.
- `AuthenticationService.swift:188` — `userId: "google_\(UUID().uuidString)"` mints a new identity
  on every sign-in; nothing can correlate across sessions. Line 125 swallows all sign-in failures
  (`case .failure: break`); lines 234/249/265 discard keychain `OSStatus` and codec errors.
- `PersistenceController.swift:58-71` — assumes `loadPersistentStores` completes synchronously;
  line 83 replaces `persistentStoreDescriptions` on a coordinator that may already hold a store.
- `PersistenceController.swift:109-117` — `initializeCloudKitSchema` runs on **every** DEBUG
  launch, synchronously on the main thread. Apple documents it as a one-off dev operation.
- `DailySuggestionService.swift:222` — `var bestScore = Double.leastNormalMagnitude` is a
  *positive* ~2.2e-308, not negative infinity. Negative scores are reachable (−54 is achievable),
  and if all five candidates score ≤ 0 the winner silently defaults to `candidates[0]` with
  `bestReason == ""` → `DailySuggestionCardView.swift:43` renders a blank line.
  *Fix: `-.greatestFiniteMagnitude`.*
- `DailySuggestionService.swift:96-106,285` — the cached technique id is written but never used to
  restore on cold launch; the cache is write-only.
- `HapticsManager.swift:13` — reads `"hapticsEnabled"` once in `init`; the only re-sync is
  `BrewGuideView.swift:119`. Turning haptics **off** in Settings has no effect anywhere until the
  user opens a brew screen. The class also lacks `@MainActor` while driving UIKit feedback
  generators.
- **`@Published` mutated without `@MainActor`** across `BrewTimerService`, `BrewJournalViewModel`,
  `BeanInventoryViewModel`, `BeansViewModel`, `MethodViewModel`, `FavouritesRecentsViewModel`,
  `DailySuggestionService`, `BrewLiveActivityService`. Concrete violation:
  `BeanFirstViewModel.swift:69` writes `scannedText` from a background `Task` (neighbouring
  writes correctly hop via `MainActor.run`).
- `BeanInventoryViewModel.swift:127` — `try? context.save()` is the **only** write path for the
  whole inventory; a validation or merge failure silently loses the edit while the UI shows
  success. Line 38-42 turns a fetch failure into an empty pantry, indistinguishable from "no beans".
- `BrewSessionViewModel.swift:19-21` and `BrewGuideView.swift:35-37` — `isLastStep` is `true` for
  an empty step list (`0 >= -1`), and in the view it drives the completion button, so an empty
  technique would immediately present the checkmark and save a bogus session.

**Views**

- `ParametersView.swift:10,63-69` — `servings` starts at `0`, so the first render shows "0 cup"
  with no segment selected and `coffeeGrams`/`waterGrams` at 0; `scaleFactor` then collapses the
  whole recipe to 0 ml. The `didLoadDefaults` guard also means a Settings change is never picked
  up on return.
- `ParametersView.swift:11-12,127,140` — the unit toggles write to local `@State` and never
  persist, while the identical-looking toggle in `WaterCalloutView.swift:33` writes straight
  through to `@AppStorage`, silently changing the app-wide preference mid-brew.
- `BrewGuideView.swift:409-427` — the Next/Complete button is never actually disabled;
  `nextButtonColor` only greys it out to *imply* disabled. Previous (line 378) is correctly
  `.disabled`. Inconsistent.
- `BrewGuideView.swift:230` — `.id(currentStepIndex)` rebuilds the whole step subtree each step,
  destroying `CumulativePourBar`'s `@State` and making its `onChange` animation (lines 57-62)
  permanently dead code.
- `BrewGuideView.swift:115-125` — `startLiveActivityIfNeeded()` is unconditional on every
  appearance, so popping back from `BrewCompleteView` requests a brand-new Live Activity for a
  brew that already ended.
- `BrewGuideView.swift:449-455` — `goToPreviousStep` never updates the Live Activity, so the lock
  screen stays on the newer step.
- `BrewGuideView.swift:552` — `isTimerPaused` is false for a configured-but-not-started timed step,
  producing `hasTimer == true` with `stepEndTime == nil` — exactly the state that renders an empty
  column in the widget (`BrewLockScreenView.swift:66-88` has no `else` branch).
- `BrewGuideView.swift:26-84` — recipe scaling, cumulative water and instruction templating all
  live in `body`; `steps` re-queries the database on every body evaluation until `.onAppear`.
- `HomeView.swift:64-79` — navigation resets through `appEnvironment.$selectedMethod`, which no
  view ever assigns, and mixes `navigationDestination(isPresented:)` with `NavigationPath` bridged
  by a hardcoded 300 ms sleep.
- `HomeView.swift:276-282` — `spotlightTechnique` filters the whole corpus and computes calendar
  ordinality on every render, from `body`.
- `TechniqueSearchView.swift:32-67` — `filteredItems` re-filters and re-sorts the entire corpus
  inside `body`, evaluated twice per render. The `.name` sort case is `break` — a no-op that only
  appears to work because `DatabaseService.swift:125` happens to pre-sort by name.
- `EquipmentListView.swift:37-39` — `techniqueCount(for:)` runs a linear lookup inside the
  `ForEach`, O(n²) in `body`.
- `BeanConfirmView.swift:5` — `@State var beanProfile: BeanProfile` initialised from an init
  parameter; a second scan reuses the view identity and the new result is silently discarded.
- `BeansView.swift:35-37` — `BeansViewModel.load` auto-assigns `selectedBean = beans.first`, so
  the UI shows a selection the user never made and carries it forward.
- `ProfileView.swift:158-161` — a fully styled, enabled "Sign in with Google" button whose action
  body is two comments. (`AuthenticationService.swift:159` guards on the placeholder client ID,
  so the flow is unreachable by design; `CoffeebrewInfo.plist` also never registers the
  `com.googleusercontent.apps.*` callback scheme.)
- `BrewSessionDetailView.swift:47` — `onAppear` unconditionally resets the notes buffer,
  discarding in-progress text on any re-appear while the field stays in edit mode.
- `PostBrewRatingView.swift:35` — toolbar "Done" silently discards rating/tags/notes while
  "Save to Journal" saves them. Two dismiss paths, one loses data.
- `ParametersView.swift:372-375` — `selectedInventoryBeanID` is set but never cleared after a brew
  unless the user taps "Brew Again", so swiping back means the next brew deducts from the previous
  bean.
- `BeanRecommendationsView.swift:50-57` — the back chevron calls `viewModel.reset()`, dumping the
  user to `.entry` and destroying the confirmed bean profile instead of returning to `.confirmBean`.
- `AddEditBeanSheet.swift:378`, `BeanDetailView.swift:88` — `Double(totalWeight)` uses the
  invariant parser; de/fr users typing `250,5` get a silent fallback to 250 g or a silent no-op.
- `BeanInventoryView.swift:138-146` — `.sheet(isPresented:)` reading `@State` mutated in the same
  tick (stale-content-closure pattern); `.sheet(item:)` is used correctly at line 147.
- `BeanInventoryView.swift:8-12` and `HomeView.swift:420-422` — `init(context:)` accepts and
  discards its parameter. `ObservableObject` stored in plain `@State` and built in `onAppear`
  causes a `ProgressView` flash on first render.
- `BeanDetailView.swift:84-92` — `.keyboardType(.decimalPad)` on a `TextField` inside an `.alert`
  is ignored on iOS.
- `StepCompletionBurst.swift:43` — writes to a `@Binding` from inside `onChange` of that same
  binding, and the `asyncAfter` chains have no cancellation.
- `Extensions.swift:131` — `.frame(maxWidth: .infinity, maxHeight: .infinity)` inside a
  `ScrollView` collapses to content height, so **every** empty state renders as a small cluster
  pinned to the top instead of centred (7 screens).
- `FlowLayout.swift:22,42` — reported width is never clamped to `maxWidth`, and
  `proposal.width ?? .infinity` mishandles SwiftUI's zero-size probe.
- `BeanProgressRing.swift:49-53` — 2500 g renders as "2,000g" (only the thousands part is
  formatted) and the separator is hardcoded, wrong for de/fr. This string feeds the accessibility
  label.
- **Empty states missing** — `BrewJournalView.swift:13-15` (filtered-to-nothing shows a "0 brews"
  header with no message), `BeanRecommendationsView.swift:19` (zero AI matches), `GrindDetailView`
  (lines 20-23 and 153-161), `BeanFirstEntryView.swift:99-107` (AI unavailable hides manual entry
  too, leaving an orphan "or" divider), `BeanInventoryView.swift:373` (all-finished pantry says
  "No Beans Yet").
- **Fixed frames / no Dynamic Type fallback** — `GrindDetailView:179-212`, `WaterCalloutView:28`
  (72 pt fixed), `DailySuggestionCardView:16,113-143`, `TechniqueSearchView:327-342` (while the
  near-identical `TechniqueRowView` *does* branch on `.accessibility1`), `BeansView:58-63`,
  `FavouritesRecentsSection:149`, `BeanFirstEntryView:258,315`.
- **Dark mode literals** — `Extensions.swift:37-40` hand-rolls a light/dark card colour instead of
  using `Constants.Colors.cardBackground`, which already ships both; `BeansView.swift:221` roast
  gradient's dark end (`0x2C1810`) is invisible on the dark card; `AddEditBeanSheet.swift:531`
  white dot with a `.black.opacity(0.15)` shadow that vanishes in dark mode.
- **Accessibility gaps** — icon-only buttons with no label at `BeanConfirmView:115,135,186`,
  `BeanRecommendationsView:50`, `BrewSessionDetailView:33` (favourite toggle, label never changes
  with state), `BrewJournalView:181`, `TechniqueSearchView:110`, `BeanInventoryView:271`,
  `TechniqueSpotlightCard:15`. `ChipViews.swift:10-54` conveys selection by colour only, with no
  `.isSelected` trait. `CumulativePourBar:63` and `BrewGuideView:337` double-read their labels.
- **Reduce Motion ungated** — `SegmentedProgressBar.swift:20-24` runs an infinite `repeatForever`
  animation with no gate (and it is dead code besides, since `currentStep` doesn't change for the
  segment that owns it); `TechniqueSpotlightCard:16,90` is ungated while the near-identical
  `TechniqueDeepDiveSection` gates correctly.
- `BrewTimerRing.swift:86` — timer warning **haptics** are gated on `accessibilityReduceMotion`,
  the wrong key; enabling Reduce Motion silently kills the "5 seconds left" cue.
- `Shared/BrewActivityAttributes.swift` vs `BrewGuideWidgetExtension/BrewActivityAttributes.swift`
  — byte-identical duplicates (verified by `diff`) in two targets that cannot share files, because
  every target syncs exactly one folder and there are no
  `PBXFileSystemSynchronizedBuildFileExceptionSet` entries. Any one-sided edit to `ContentState`
  produces a Live Activity that starts but never updates, with no compiler error.
- `BrewDynamicIslandViews.swift:147-157` — `methodIcon` matches on "french"/"aero"/"espresso"/
  "moka", but the value passed is `methodCategory`, whose actual values are
  "Pour Over"/"Immersion"/"Pressure"/"Cold Brew"/"Stovetop & Traditional"/"Machine". Only "pour"
  and "cold" can ever match; everything else falls through to the default, and it breaks entirely
  for localized categories.
- `BrewJournalViewModel.swift:177-181` — `mostBrewedMethod` groups on `methodName`, which holds a
  **category**. The stat labelled "most brewed method" is actually "most brewed category", and
  `BrewJournalViewModelTests.swift:229` bakes in the confusion.
- `BeanProfile.swift:6-7` — `let id = UUID()` on a `Hashable` struct makes two identical profiles
  compare unequal, breaking any `Set`/dedup/`contains`.
- Tests: `ViewModelTests.swift:124-129` is named for `MethodViewModel` but exercises
  `BrewSessionViewModel` (duplicate of line 77); `BrewTimerServiceTests.swift:108-113`
  (`testStepProgressFullWhenComplete`) asserts progress is *zero*; several `@MainActor` overrides
  of non-isolated `setUp`/`tearDown` become hard errors under Swift 6.

---

## Low issues

- `Extensions.swift:89-96` — `shortFormattedTime` formats negative values as `"0:-5"`.
- `Extensions.swift:80-96` — hardcoded English `"min"`/`"s"` surfaced on 5 screens.
- `CumulativePourBar.swift:31` — `geo.size.width * prevFraction` has no lower clamp; a negative
  `previousMl` yields a negative frame width.
- `AddEditBeanSheet.swift:499-521` — `peakStartFraction`/`peakEndFraction` unclamped; unreachable
  with shipped data but unguarded.
- `SegmentedProgressBar.swift:10` — `ForEach(1...totalSteps)` traps on 0, saved only by the
  `steps.isEmpty` guard in the parent.
- `PostBrewRatingView.swift:155` — array literal indexed by `rating`; safe only because
  `RatingStarsView` emits 1...5.
- `DailySuggestionService.swift:242` — `weights[currentSeason]` is unchecked; safe today because
  every literal has 4 elements.
- `DailySuggestionService.swift:194` — mixes a UTC epoch with the device calendar, shifting the
  daily seed by one day west of UTC.
- `DailySuggestionService.swift:181,320` — `isLoading` is set true and false within the same
  synchronous call, so no view can ever render the loading state.
- `DailySuggestionService.swift:333-358` — fetches **every** `BrewSession` row with no
  `fetchLimit` on each recompute, on the main thread.
- `DailySuggestionService.swift:20-25` and `AppEnvironment.swift:17-26` — UserDefaults keys are
  prefixed but use `UserDefaults.standard`, not an App Group suite, so the widget cannot read them.
- `BrewLiveActivityService.swift:75-120` — each mutator fires an independent unstructured `Task`;
  rapid Next taps can deliver step N+1 before step N.
- `BrewJournalViewModel.swift:143-149` — the row is removed from the UI before the store write,
  and `save()` only prints on failure.
- `BrewGuideView.swift:468` — a fresh `BrewJournalViewModel` is built at completion, running a
  full unfiltered fetch just to write one row.
- `BeanInventoryViewModel.swift:67` — `beans.insert(bean, at: 0)` contradicts the fetch ordering.
- `BeanInventoryViewModel.swift:212` — `import SwiftUI` at the *bottom* of the file, and a view
  model vending a `Color`.
- `PersistenceController.swift:98-106` — the observer token is discarded and never removed; leaks
  one observer per `PersistenceController(inMemory:)` in tests.
- `AddEditBeanSheet.swift:14,107` — `roastDate` defaults to `Date()`, so enabling "I know the roast
  date" instantly reports "Day 0 — Degassing".
- `BeanConfirmView.swift:172-177` — the dimmed background tests the untrimmed name while
  `.disabled` tests the trimmed one, so `"   "` looks enabled.
- `ParametersView.swift:42` — `Int(...)` truncates the °F conversion instead of rounding
  (2 °C → 35 °F, should be 36). The formula itself is correct.
- `BrewCompleteView.swift:5` — unused `dismiss`; with `navigationBarBackButtonHidden(true)` the
  only exit is "Brew Again".
- `OnboardingView.swift:39,78` — animation applied twice (`.animation` plus `withAnimation`).
- `TechniqueSpotlightCard.swift:102` — `story.prefix(200)` truncates by grapheme mid-word (badly
  wrong for ja) and is redundant with the `.lineLimit(4)` already applied.
- `DailySuggestionCardView.swift:55` — nil-check-then-force-unwrap
  (`deepDive.creator?.name != nil ? "...\(deepDive.creator!.name)..."`). Safe today; a refactor
  will break it. This is the **only** force-unwrap in the app target — there is no `try!` or `as!`
  anywhere.
- `DailySuggestionCardView.swift:124` — `ForEach(1...5)` difficulty dots while `methods.json`
  tops out at difficulty 4, so the fifth dot never fills.
- `grind_sizes.json` — "Extra Fine" has `comandante_min = comandante_max = 0` with
  `comandante_clicks: "N/A"`, a degenerate range for any bar UI.
- `techniques.json` — one `youtube_id` (`j6VlT_jUVPc`) is reused by both Turkish techniques.
- Dead declarations: `BrewTimerRing.swift:7,12`, `BeanDetailView.swift:10`,
  `BeanConfirmView.swift:6`, `BeanRecommendationsView.swift:7`, `BeanScannerView.swift:2,6`
  (`import AVFoundation` unused — capture is `UIImagePickerController`, not `AVCaptureSession`).
- `VideoThumbnailCard.swift:24-33` — `AsyncImage` has no `.failure` phase, so a network error
  spins forever. `isExpanded` is also one-way with no collapse or stop control.
- Tests: `ExtensionTests.swift:43-62` — four tests asserting `XCTAssertNotNil` on a non-optional
  `Color` (statically always true); `ViewModelTests.swift:117-122` same on `[BrewMethod]`;
  `AppEnvironmentTests.swift:35-46` never dirties the state it claims to reset;
  `ModelTests.swift:20-26` asserts English literals against `String(localized:)`.

---

## Info / suggestions

- `IPHONEOS_DEPLOYMENT_TARGET = 26.2` on all four targets, with `SWIFT_VERSION = 5.0`. Consider
  whether the deployment floor is intentional; Swift 6 language mode would catch much of the
  concurrency class above.
- `PRODUCT_BUNDLE_IDENTIFIER = Aziz.Coffeebrew` is not reverse-DNS. The widget is correctly nested
  as `Aziz.Coffeebrew.BrewGuideWidgetExtension`.
- `CoffeebrewInfo.plist:9-28` — the ATS exception dicts for youtube.com/ytimg.com assert only ATS
  defaults (`NSExceptionAllowsInsecureHTTPLoads: false`, `NSIncludesSubdomains: true`), so they
  grant nothing. Dead config that still invites App Review questions.
- `Coffeebrew.entitlements` sits inside the synchronized root group, risking it being copied into
  the bundle as a resource.
- No `UIRequiredDeviceCapabilities`, worth considering since `OnDeviceAIAvailability` gates on
  iPhone 15 Pro+. `UILaunchScreen` is *not* missing — generated via
  `INFOPLIST_KEY_UILaunchScreen_Generation`.
- `AuthenticationService.swift:156-157` — placeholder OAuth strings only. **No live API key,
  token or secret is committed anywhere in the repo.** Keychain usage correctly uses
  `kSecAttrAccessibleAfterFirstUnlock`.
- `Constants.swift:15-16` — `backgroundLight`/`backgroundDark` have no references anywhere;
  `accentGold` (line 17) duplicates `accent` (line 7); the widget has a third hardcoded copy.
- `TechniqueRecommendation.swift:38` — the "exactly 5" requirement lives only in prose; use
  `@Guide(.count(5))`.
- `BeanProfile.swift:34-40` — `init(from coffeeBean:)` leaves `region`, `process`, `altitude` and
  `variety` unset, so inventory-sourced profiles feed a thinner prompt than scanned ones.
- `AIRecommendationService.swift:13` — a fresh `LanguageModelSession` per call (correct), but
  nothing calls `prewarm()`, so every request pays cold-start latency.

---

## Timer logic violations

**The bug class the brief predicted is absent.** Zero steps have a single clock-position title
(`"1:30"`) whose value equals `duration_seconds`, and zero range-titled steps use the *end*
marker as the duration. That pattern has evidently already been cleaned up. What remains:

### Instruction states a duration that `duration_seconds` contradicts

| Technique | Step # | Title | Current | Correct | Reason |
|-----------|--------|-------|---------|---------|--------|
| V60 – James Hoffmann Ultimate | 4 | `0:10-0:45` | 35 | 45 | "wait up to 45 seconds" |
| Espresso (Machine) | 1 | `Prep` | 0 | 1350 | "Warm up machine for 15-30 min" (midpoint) |
| South Indian Filter (Kaapi) | 5 | `Step 4` | 0 | 1050 | "let decoction drip (15-20 min)" |
| Turkish Coffee (Traditional) | 10 | `Step 10` | 0 | 90 | "Wait 1-2 min to sip" |
| Drip Coffee Maker (Automatic) | 6 | `Step 6` | 0 | 390 | "Brewing completes in 5-8 minutes" |
| Single Serve Pod | 2 | `Step 2` | 0 | 38 | "Allow it to heat up (15-60 seconds)" |
| Single Serve Pod | 6 | `Step 6` | 0 | 20 | "~25-40ml in 15-25s" |
| Nitro Cold Brew | 7 | `Step 7` | 0 | 3600 | "Refrigerate at least 1 hour" |

Judgement call on the long ones: a 22-minute machine-warm-up timer is probably not what you want
in a step countdown. The consistent fix is to keep `duration_seconds = 0` and move the wait into
the instruction text, or introduce a separate "passive wait" field — but **the current state,
where the text promises a wait and the timer does nothing, is the worst of both.**

### Title range disagrees with the duration

| Technique | Step # | Title | Current | Span implied by title | Note |
|-----------|--------|-------|---------|----------------------|------|
| Cupping (Professional Tasting) | 8 | `4:30-9:00` | 390 | 270 | Duration matches "cool 5-8 minutes"; the **title** is wrong |
| Chemex | 4 | `0:00-0:45` | 38 | 45 | Duration = midpoint of "30-45 seconds"; title rounds up. Acceptable |
| Kalita Wave | 4 | `0:00-0:45` | 38 | 45 | Same as above. Acceptable |
| Clever Dripper | 6 | `2:30-3:15` | 38 | 45 | Same as above. Acceptable |
| Hario Switch | 6 | `2:00-3:00` | 53 | 60 | Duration = midpoint of "45-60 seconds". Correct |
| AeroPress WAC 2024 | 6 | `1:20-1:30` | 0 | 10 | Part of the duplicate block — deleted by the Critical fix |
| Osmotic Flow V60 | 7 | `3:00-4:00+` | 0 | 60 | Open-ended drawdown; 0 is defensible |
| French Press – Hoffmann | 7, 8 | `9:00-12:00` | 0 | 180 | Action steps (plunge, pour); 0 is correct |

### Last step has a non-zero duration — all nine are correct as-is

V60 Standard, V60 Hoffmann, V60 Winton, Scott Rao V60, Kalita Wave, Melitta, Nel Drip,
Percolator, Turkish Competition. Each final step is an explicit "allow full drawdown" or
"let grounds settle" wait, so the brief's "last step must be 0" rule does not apply. **Do not
zero these.**

### Pure-action steps carrying a duration — 8 to review

`Clever Dripper` 3 (60 s, "Place lid on to retain heat") and 4 (90 s, "Stir gently"), and
`French Press (Standard)` 5 (220 s, "Place lid on… Do not press yet") are the clearest cases where
the number is really the *following* wait, not the action. The five V60 Winton / V60 Standard pour
steps (15–90 s) are legitimate pour durations.

---

## Test coverage gaps

Critical paths with **zero** unit tests:

1. `AIRecommendationService` — entire file. The app's headline feature.
2. `BrewGuideView`'s brew logic — the *actual* shipping implementation. `BrewSessionViewModel`,
   which the tests do cover, is dead code.
3. `DailySuggestionService` — 439 lines, five-stage scoring, seasonal weighting, streaks,
   notification scheduling.
4. `DatabaseService` — `DatabaseServiceTests` tests raw `JSONDecoder` round-trips on inline
   literals and never instantiates the service. `load(_:languageCode:)`, `buildIndices()`,
   `reload()` and all eight query methods are untested.
5. `TechniqueDeepDive` decoding — 10 techniques ship `deep_dive` payloads including the
   hand-written `init(from:)` with `?? []` defaults; none is decoded in any test.
6. `BeanProfile` / `TechniqueRecommendation` / `GrindSize` — no test file at all for `GrindSize`.
7. Live Activity lifecycle — only the pure `makeState` is covered; `startActivity`, `updateStep`,
   `pauseTimer`, `resumeTimer`, `endActivity` are untested.
8. `PersistenceController`'s CloudKit→local fallback — i.e. exactly the path the model
   incompatibility forces every launch into.
9. `AuthenticationService` — Keychain save/load/delete, `UserProfile.initials`.
10. `BeanScannerService` — Vision OCR path and all three `ScanError` cases.
11. Deep-link routing (`AppEntry.swift:17-24`).
12. The `imageName` / `methodPhoto` asset-name maps — 89 hardcoded string pairs with silent
    fallbacks; nothing asserts they resolve to real assets.
13. `Array.subscript(safe:)`.

**Also broken right now:** `CoffeebrewUITests` asserts `app.staticTexts["Brewing Methods"]`
(lines 29, 79) while the app renders `Text("Brew Methods")` (`HomeView.swift:311`), and line 83
matches a predicate on `'difficulty'` that only exists on a pushed screen. Two UI tests fail
deterministically and a third always hits its own `XCTFail`.

---

## Checked and cleared

Recorded so these don't get re-raised:

- **Files are not missing from the Xcode project.** `objectVersion = 77` uses
  `PBXFileSystemSynchronizedRootGroup`; membership is folder-derived. All 20 JSON files are
  bundled.
- **`NSSupportsLiveActivities` is not missing** — injected via
  `INFOPLIST_KEY_NSSupportsLiveActivities = YES` (pbxproj:492/527).
- **Camera and photo-library usage descriptions are both present** and correct.
- **`BrewTimerService` does not drift** — `tick()` uses wall-clock `Date()` deltas plus
  accumulators, and pause/resume preserves `secondsRemaining` correctly.
- **No retain cycles.** The `Timer` sink uses `[weak self]`; `Task`/`asyncAfter` closures either
  capture a struct `View` or use `[weak self]`.
- **No force-try, no force-cast, one guarded force-unwrap.** No live secrets committed.
- **Water maths are internally correct** — every technique's step water sums to exactly
  `ratio × 15 g`. Only the WAC-2024 technique is off, and only because of the duplicate block.
- **Cross-locale data is numerically identical** — zero drift in durations, water, temperatures,
  ratios or match scores across en/de/fr/ja.
- **`filterRating == 0` correctly means "all ratings"**, and `averageRating` correctly divides by
  only the rated sessions with a zero guard.
- **All 11 `youtube_id`s are valid 11-character slugs.** All `match_score`s are integers in 0–100.
  No empty or duplicate `flavour_notes`. No orphan foreign keys.
- **Five of six colorsets have proper dark variants** — only `AccentColor` is broken.
- **`VideoThumbnailCard` correctly defers `WKWebView` creation until tap** — the brief's concern
  does not apply.
- **Unit conversion formulas are correct** (`C × 9/5 + 32`, `ml / 29.5735`).
- **`ratio_water_coffee` outside 10–20** for espresso (2.0), AeroPress competition recipes
  (5.5, 7.2) and cold brew/phin/nitro (8.0) is correct for those methods — the brief's validation
  band is what needs widening, not the data.

---

## Recommended fix order

1. **`CODE_SIGN_ENTITLEMENTS`** — one line; without it three major features cannot work at all.
2. **`@AppStorage` → `@Published`** in `AppEnvironment` — unblocks onboarding, language switching
   and every Settings toggle.
3. **Delete `steps.json` rows 107–113** (×4 locales) and set `aeropress-standardupright`
   `step_count: 7` — removes the duplicate-ID hazard and fixes two techniques.
4. **Guard the widget's three trap sites** and return early from `startLiveActivityIfNeeded()`
   when `steps.isEmpty`.
5. **Fix the journal write** — thread the real bean and serving size into `saveSession`; every
   day this ships writes permanently wrong history.
6. **Re-present the post-brew rating sheet** from `BrewCompleteView`.
7. **Make the Core Data model CloudKit-compatible** (four attributes) and surface store-load
   errors instead of silently falling back.
8. **Stop the timer on disappear** and add `deinit`; fix the dead auto-start condition.
9. **Wire the deep links** — read `shouldShowActiveBrew`/`shouldShowDailySuggestion`, add a
   notification delegate.
10. **Pass the shared `DatabaseService`** into `AIRecommendationService`; move JSON loading off
    the main thread.
11. **Accessibility batch** — `RatingStarsView`, `BrewTimerRing`, `SegmentedProgressBar`,
    `WaterCalloutView`, then the icon-only button labels.
12. **`FlowLayout` measurement** and the empty-state centring fix — both are one-line changes
    affecting 7–8 screens each.
13. **Fix the two failing UI tests**, then start closing the coverage gaps, beginning with the
    brew logic that actually ships.
14. **Data pass** — the 8 instruction/duration mismatches, `total_time_seconds`, and the
    all-zero-duration techniques.
15. **`AccentColor` colorset** and the white-on-gold contrast sweep.
