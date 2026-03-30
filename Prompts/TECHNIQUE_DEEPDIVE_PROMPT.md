# Task: Technique Deep-Dive — Expandable Section on Technique Selection Screen

## Overview

Add a collapsible **deep-dive section** to the existing technique selection screen.
When expanded, it reveals: origin story, creator/inventor bio, tasting notes,
common mistakes & tips, and embedded YouTube video(s).

All content is data-driven from the existing JSON database — add new fields to the
technique schema. No new screens. No new navigation. Pure in-place expansion.

---

## Step 1 — JSON database schema additions

Add these optional fields to each technique object in the existing JSON files.
All fields are optional — techniques without deep-dive content show nothing.

```json
{
  "id": "v60_hoffmann",
  "name": "James Hoffmann Method",

  "deepDive": {
    "originStory": "String — 1–3 paragraphs on how/where/when the technique was developed.",
    "creator": {
      "name": "James Hoffmann",
      "bio": "String — 2–3 sentences on who they are and why they matter in coffee.",
      "url": "https://www.jameshoffmann.co.uk"
    },
    "tastingNotes": "String — what the brewer should expect in the cup: body, acidity, clarity, finish.",
    "commonMistakes": [
      "String — one concise mistake per item, e.g. 'Pouring too fast during the bloom'"
    ],
    "tips": [
      "String — one actionable tip per item"
    ],
    "videos": [
      {
        "title": "String — display title",
        "youtubeId": "String — 11-character YouTube video ID only, e.g. 'AI4ynXzkSQo'",
        "durationLabel": "String — e.g. '6:24'"
      }
    ]
  }
}
```

Populate deep-dive content for at minimum: all James Hoffmann methods, Tetsu Kasuya
4:6, Scott Rao method, WAC 2024/2025 competition winners, AeroPress inverted,
and Turkish Coffee. Leave `deepDive` absent for techniques without notable history.

---

## Step 2 — Update Technique model

In the existing `Technique.swift` (or equivalent model file), add:

```swift
struct TechniqueDeepDive: Codable {
    let originStory: String?
    let creator: TechniqueCreator?
    let tastingNotes: String?
    let commonMistakes: [String]
    let tips: [String]
    let videos: [TechniqueVideo]

    // Safe defaults so existing techniques without deepDive parse cleanly
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        originStory    = try c.decodeIfPresent(String.self,              forKey: .originStory)
        creator        = try c.decodeIfPresent(TechniqueCreator.self,    forKey: .creator)
        tastingNotes   = try c.decodeIfPresent(String.self,              forKey: .tastingNotes)
        commonMistakes = try c.decodeIfPresent([String].self,            forKey: .commonMistakes) ?? []
        tips           = try c.decodeIfPresent([String].self,            forKey: .tips)           ?? []
        videos         = try c.decodeIfPresent([TechniqueVideo].self,    forKey: .videos)         ?? []
    }
}

struct TechniqueCreator: Codable {
    let name: String
    let bio: String
    let url: String?
}

struct TechniqueVideo: Codable, Identifiable {
    var id: String { youtubeId }
    let title: String
    let youtubeId: String
    let durationLabel: String?

    var thumbnailURL: URL? {
        URL(string: "https://img.youtube.com/vi/\(youtubeId)/hqdefault.jpg")
    }

    var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(youtubeId)")
    }
}
```

Add `deepDive: TechniqueDeepDive?` as an optional property on the existing `Technique` struct.

---

## Step 3 — YouTubePlayerView (embedded WKWebView player)

Create `Views/Components/YouTubePlayerView.swift`:

```swift
import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let youtubeId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { margin: 0; padding: 0; background: #000; }
          iframe { width: 100%; height: 100%; border: none; }
        </style>
        </head>
        <body>
        <iframe
          src="https://www.youtube.com/embed/\(youtubeId)?playsinline=1&rel=0"
          allowfullscreen>
        </iframe>
        </body>
        </html>
        """
        webView.loadHTMLString(embedHTML, baseURL: nil)
    }
}
```

Add `NSAppTransportSecurity` exception for `youtube.com` and `ytimg.com` in Info.plist:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>youtube.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key><false/>
            <key>NSIncludesSubdomains</key><true/>
        </dict>
        <key>ytimg.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key><false/>
            <key>NSIncludesSubdomains</key><true/>
        </dict>
    </dict>
</dict>
```

---

## Step 4 — VideoThumbnailCard

Show a tappable thumbnail that expands inline into the embedded player.
Avoids loading a WKWebView for every video until the user taps.

Create `Views/Components/VideoThumbnailCard.swift`:

```swift
import SwiftUI

struct VideoThumbnailCard: View {
    let video: TechniqueVideo
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                YouTubePlayerView(youtubeId: video.youtubeId)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                thumbnailButton
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }

    private var thumbnailButton: some View {
        Button { isExpanded = true } label: {
            ZStack {
                // Thumbnail image
                AsyncImage(url: video.thumbnailURL) { image in
                    image.resizable().aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                        .aspectRatio(16/9, contentMode: .fit)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Play button overlay
                Circle()
                    .fill(.black.opacity(0.65))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                    )

                // Duration badge
                if let dur = video.durationLabel {
                    Text(dur)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

---

## Step 5 — TechniqueDeepDiveSection

The expandable section itself. Drop this into the existing technique selection screen.

Create `Views/TechniqueList/TechniqueDeepDiveSection.swift`:

```swift
import SwiftUI

struct TechniqueDeepDiveSection: View {
    let deepDive: TechniqueDeepDive
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // ── Toggle header ──────────────────────────────────────────────
            Button {
                withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("Deep dive", systemImage: "book.pages")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brewGold)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(reduceMotion ? .none : .spring(response: 0.3), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Expanded content ───────────────────────────────────────────
            if isExpanded {
                VStack(alignment: .leading, spacing: 20) {

                    // Origin story
                    if let story = deepDive.originStory {
                        DeepDiveBlock(icon: "map", title: "Origin story", tint: .brewGold) {
                            Text(story)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Creator bio
                    if let creator = deepDive.creator {
                        DeepDiveBlock(icon: "person.fill", title: creator.name, tint: .brewGold) {
                            Text(creator.bio)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let urlString = creator.url, let url = URL(string: urlString) {
                                Link("Learn more", destination: url)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.brewGold)
                            }
                        }
                    }

                    // Tasting notes
                    if let notes = deepDive.tastingNotes {
                        DeepDiveBlock(icon: "cup.and.saucer.fill", title: "What to expect in the cup", tint: .brewGold) {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Common mistakes
                    if !deepDive.commonMistakes.isEmpty {
                        DeepDiveBlock(icon: "exclamationmark.triangle", title: "Common mistakes", tint: Color.orange) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(deepDive.commonMistakes, id: \.self) { mistake in
                                    Label(mistake, systemImage: "xmark.circle.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .symbolRenderingMode(.multicolor)
                                }
                            }
                        }
                    }

                    // Tips
                    if !deepDive.tips.isEmpty {
                        DeepDiveBlock(icon: "lightbulb.fill", title: "Tips", tint: Color.teal) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(deepDive.tips, id: \.self) { tip in
                                    Label(tip, systemImage: "checkmark.circle.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .symbolRenderingMode(.multicolor)
                                }
                            }
                        }
                    }

                    // Videos
                    if !deepDive.videos.isEmpty {
                        DeepDiveBlock(icon: "play.rectangle.fill", title: "Watch", tint: Color.red) {
                            VStack(spacing: 10) {
                                ForEach(deepDive.videos) { video in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(video.title)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                        VideoThumbnailCard(video: video)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .move(edge: .top))
                )
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// ── Reusable content block ─────────────────────────────────────────────────

private struct DeepDiveBlock<Content: View>: View {
    let icon: String
    let title: String
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }
}
```

---

## Step 6 — Wire into the existing technique selection screen

In the existing `TechniqueListView` (or equivalent), find the per-technique row or
detail area and add `TechniqueDeepDiveSection` conditionally:

```swift
// Inside the technique cell / row, after the existing technique info:
if let deepDive = technique.deepDive {
    TechniqueDeepDiveSection(deepDive: deepDive)
        .padding(.horizontal, 16)
        .padding(.top, 8)
}
```

If the technique list uses a `List` or `ForEach`, place the section inside the same
cell so it expands inline without any navigation push.

---

## Files to create / modify

| File | Action |
|------|--------|
| `techniques.json` (or equivalent data file) | Modify — add `deepDive` field to qualifying techniques |
| `Models/Technique.swift` | Modify — add `TechniqueDeepDive`, `TechniqueCreator`, `TechniqueVideo` |
| `Views/Components/YouTubePlayerView.swift` | Create |
| `Views/Components/VideoThumbnailCard.swift` | Create |
| `Views/TechniqueList/TechniqueDeepDiveSection.swift` | Create |
| `Views/TechniqueList/TechniqueListView.swift` | Modify — inject section per technique |
| `Info.plist` | Modify — add ATS exceptions for youtube.com and ytimg.com |

---

## Checklist

- [ ] `deepDive` field added to JSON schema and populated for key techniques
- [ ] `TechniqueDeepDive`, `TechniqueCreator`, `TechniqueVideo` models decode cleanly
- [ ] Techniques without `deepDive` field parse without error (all fields optional)
- [ ] `YouTubePlayerView` loads inline with `playsinline=1` (no full-screen forced)
- [ ] `VideoThumbnailCard` shows thumbnail + play button; WKWebView only loads on tap
- [ ] `TechniqueDeepDiveSection` toggle animates with chevron rotation
- [ ] Expand/collapse respects `@Environment(\.accessibilityReduceMotion)`
- [ ] ATS exceptions added for `youtube.com` and `ytimg.com` in Info.plist
- [ ] `Link("Learn more")` for creator URL opens in Safari
- [ ] Section only renders if `technique.deepDive != nil` — no empty cards
- [ ] Dark mode verified across all new views
- [ ] VoiceOver: toggle button has meaningful accessibility label
