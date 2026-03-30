# Task: Implement Brew Journal with Session History, Ratings & Notes

## Overview

Add a **Brew Journal** feature to BrewGuide that automatically saves a session when the user
completes a brew, and lets them view history, add a star rating, write tasting notes, and
re-brew a past session in one tap.

Use **Core Data** for persistence (not SwiftData — target iOS 16+).
Follow the existing MVVM architecture and match the app's existing visual style exactly.

---

## Architecture

```
CoreData Stack
└── PersistenceController (singleton)

Models/
└── BrewSession+CoreDataClass.swift      (NSManagedObject subclass)
└── BrewSession+CoreDataProperties.swift (generated properties)
└── BrewGuide.xcdatamodeld               (Core Data model — add entity here)

ViewModels/
└── BrewJournalViewModel.swift           (owns fetch, save, delete, filter logic)

Views/
└── BrewJournalView.swift                (main history list)
└── BrewSessionDetailView.swift          (single session — rating, notes, re-brew)
└── BrewSessionRowView.swift             (list row component)
└── PostBrewRatingView.swift             (sheet shown after brew completes)
└── RatingStarsView.swift                (reusable star rating component)
```

---

## Step 1 — Core Data model

Open (or create) `BrewGuide.xcdatamodeld` and add an entity called `BrewSession` with
these attributes:

| Attribute | Type | Notes |
|-----------|------|-------|
| `id` | UUID | default: auto-generated |
| `brewedAt` | Date | timestamp when brew completed |
| `methodName` | String | e.g. "French Press" |
| `equipmentName` | String | e.g. "Hario V60" |
| `techniqueName` | String | e.g. "James Hoffmann Method" |
| `beanName` | String? | optional — user may skip bean selection |
| `beanOrigin` | String? | optional |
| `roastLevel` | String? | optional — "Light", "Medium", etc. |
| `servingSize` | Int16 | number of cups |
| `coffeeAmountGrams` | Double | grams of coffee used |
| `waterAmountMl` | Double | ml of water used |
| `grindSize` | String | e.g. "Medium-Coarse" |
| `waterTempC` | Double | water temperature in Celsius |
| `rating` | Int16 | 0–5 stars, 0 = unrated |
| `notes` | String? | optional freeform tasting notes |
| `flavourTags` | String? | comma-separated tags e.g. "Fruity,Bright,Sweet" |
| `totalBrewTimeSeconds` | Int32 | actual time from first step to last |
| `isFavourite` | Bool | default false |

Set the entity's Codegen to **"Class Definition"** so Xcode auto-generates the NSManagedObject
subclass files.

---

## Step 2 — PersistenceController

Create `Services/PersistenceController.swift`:

```swift
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        // Insert 5 sample sessions for SwiftUI previews
        let context = controller.container.viewContext
        for i in 0..<5 {
            let session = BrewSession(context: context)
            session.id = UUID()
            session.brewedAt = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            session.methodName = ["Pour Over", "French Press", "AeroPress"][i % 3]
            session.equipmentName = ["Hario V60", "French Press", "AeroPress"][i % 3]
            session.techniqueName = ["Standard Pour", "James Hoffmann Method", "Inverted"][i % 3]
            session.beanName = "Ethiopia Yirgacheffe"
            session.beanOrigin = "Ethiopia"
            session.roastLevel = "Light"
            session.servingSize = Int16(i % 3 + 1)
            session.coffeeAmountGrams = Double(15 + i * 2)
            session.waterAmountMl = Double(250 + i * 30)
            session.grindSize = "Medium"
            session.waterTempC = 94.0
            session.rating = Int16(i % 6)
            session.notes = i % 2 == 0 ? "Lovely bright cup, slightly acidic finish." : nil
            session.flavourTags = "Fruity,Bright"
            session.totalBrewTimeSeconds = Int32(240 + i * 30)
            session.isFavourite = i == 1
        }
        try? context.save()
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BrewGuide")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("CoreData load failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
```

Inject the managed object context into the environment in `@main` App struct:

```swift
.environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
```

---

## Step 3 — BrewJournalViewModel

Create `ViewModels/BrewJournalViewModel.swift`:

```swift
import CoreData
import SwiftUI

final class BrewJournalViewModel: ObservableObject {
    @Published var sessions: [BrewSession] = []
    @Published var searchText: String = ""
    @Published var filterRating: Int = 0        // 0 = all
    @Published var filterFavourites: Bool = false
    @Published var sortOrder: SortOrder = .newest

    enum SortOrder: String, CaseIterable {
        case newest = "Newest first"
        case oldest = "Oldest first"
        case highestRated = "Highest rated"
        case mostUsed = "Most used method"
    }

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        fetchSessions()
    }

    // MARK: - Fetch

    func fetchSessions() {
        let request: NSFetchRequest<BrewSession> = BrewSession.fetchRequest()
        request.predicate = buildPredicate()
        request.sortDescriptors = buildSortDescriptors()
        do {
            sessions = try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
        }
    }

    private func buildPredicate() -> NSCompoundPredicate {
        var predicates: [NSPredicate] = []
        if !searchText.isEmpty {
            predicates.append(NSPredicate(
                format: "techniqueName CONTAINS[cd] %@ OR equipmentName CONTAINS[cd] %@ OR beanName CONTAINS[cd] %@ OR notes CONTAINS[cd] %@",
                searchText, searchText, searchText, searchText
            ))
        }
        if filterRating > 0 {
            predicates.append(NSPredicate(format: "rating >= %d", filterRating))
        }
        if filterFavourites {
            predicates.append(NSPredicate(format: "isFavourite == YES"))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func buildSortDescriptors() -> [NSSortDescriptor] {
        switch sortOrder {
        case .newest:       return [NSSortDescriptor(key: "brewedAt", ascending: false)]
        case .oldest:       return [NSSortDescriptor(key: "brewedAt", ascending: true)]
        case .highestRated: return [NSSortDescriptor(key: "rating", ascending: false),
                                    NSSortDescriptor(key: "brewedAt", ascending: false)]
        case .mostUsed:     return [NSSortDescriptor(key: "techniqueName", ascending: true),
                                    NSSortDescriptor(key: "brewedAt", ascending: false)]
        }
    }

    // MARK: - Save session (called from BrewSessionViewModel when brew completes)

    func saveSession(
        methodName: String,
        equipmentName: String,
        techniqueName: String,
        beanName: String?,
        beanOrigin: String?,
        roastLevel: String?,
        servingSize: Int,
        coffeeGrams: Double,
        waterMl: Double,
        grindSize: String,
        waterTempC: Double,
        totalBrewTimeSeconds: Int
    ) -> BrewSession {
        let session = BrewSession(context: context)
        session.id = UUID()
        session.brewedAt = Date()
        session.methodName = methodName
        session.equipmentName = equipmentName
        session.techniqueName = techniqueName
        session.beanName = beanName
        session.beanOrigin = beanOrigin
        session.roastLevel = roastLevel
        session.servingSize = Int16(servingSize)
        session.coffeeAmountGrams = coffeeGrams
        session.waterAmountMl = waterMl
        session.grindSize = grindSize
        session.waterTempC = waterTempC
        session.totalBrewTimeSeconds = Int32(totalBrewTimeSeconds)
        session.rating = 0
        session.isFavourite = false
        save()
        fetchSessions()
        return session
    }

    // MARK: - Update

    func updateRating(_ rating: Int, for session: BrewSession) {
        session.rating = Int16(rating)
        save()
        fetchSessions()
    }

    func updateNotes(_ notes: String, for session: BrewSession) {
        session.notes = notes.isEmpty ? nil : notes
        save()
        fetchSessions()
    }

    func updateFlavourTags(_ tags: [String], for session: BrewSession) {
        session.flavourTags = tags.isEmpty ? nil : tags.joined(separator: ",")
        save()
    }

    func toggleFavourite(_ session: BrewSession) {
        session.isFavourite.toggle()
        save()
        fetchSessions()
    }

    // MARK: - Delete

    func delete(_ session: BrewSession) {
        context.delete(session)
        save()
        fetchSessions()
    }

    func deleteAll() {
        sessions.forEach { context.delete($0) }
        save()
        fetchSessions()
    }

    // MARK: - Helpers

    private func save() {
        guard context.hasChanges else { return }
        do { try context.save() } catch { print("Save error: \(error)") }
    }

    var totalBrews: Int { sessions.count }

    var averageRating: Double {
        let rated = sessions.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return Double(rated.map { Int($0.rating) }.reduce(0, +)) / Double(rated.count)
    }

    var mostBrewedMethod: String? {
        let counts = Dictionary(grouping: sessions, by: \.methodName)
            .mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var flavourTags: [String] {
        Array(Set(sessions
            .compactMap(\.flavourTags)
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        )).sorted()
    }
}
```

---

## Step 4 — RatingStarsView (reusable component)

Create `Views/Journal/RatingStarsView.swift`:

```swift
import SwiftUI

struct RatingStarsView: View {
    let rating: Int          // current value 0-5
    let maxRating: Int = 5
    var size: CGFloat = 24
    var interactive: Bool = false
    var onRatingChanged: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.brewGold : Color.secondary.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
                    .onTapGesture {
                        guard interactive else { return }
                        // Tap same star again to clear rating
                        let newRating = star == rating ? 0 : star
                        onRatingChanged?(newRating)
                    }
            }
        }
        .animation(.spring(response: 0.3), value: rating)
    }
}
```

Note: `Color.brewGold` should match the app's existing gold accent color. Add it to
`Color+Extensions.swift` if not already there:
```swift
extension Color {
    static let brewGold = Color("BrewGold")  // or use the hex directly if no asset exists
}
```

---

## Step 5 — PostBrewRatingView

This sheet appears immediately after a brew completes. Keep it quick — rating + tags only.
Notes are optional and can be added later from the journal.

Create `Views/Journal/PostBrewRatingView.swift`:

```swift
import SwiftUI

struct PostBrewRatingView: View {
    let session: BrewSession
    @ObservedObject var journalViewModel: BrewJournalViewModel
    @Binding var isPresented: Bool

    @State private var selectedRating: Int = 0
    @State private var selectedTags: Set<String> = []
    @State private var quickNote: String = ""
    @FocusState private var noteFieldFocused: Bool

    private let suggestedTags = [
        "Fruity", "Floral", "Bright", "Sweet", "Chocolatey",
        "Nutty", "Earthy", "Smoky", "Bitter", "Balanced",
        "Acidic", "Smooth", "Bold", "Mild", "Complex"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.brewGold)
                        Text("Brew complete")
                            .font(.title2.weight(.semibold))
                        Text(session.techniqueName ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    Divider()

                    // Star rating
                    VStack(spacing: 12) {
                        Text("How was it?")
                            .font(.headline)
                        RatingStarsView(
                            rating: selectedRating,
                            size: 36,
                            interactive: true,
                            onRatingChanged: { selectedRating = $0 }
                        )
                        if selectedRating > 0 {
                            Text(ratingLabel(selectedRating))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .animation(.spring(response: 0.3), value: selectedRating)

                    // Flavour tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Flavour notes")
                            .font(.headline)
                        FlowLayout(spacing: 8) {
                            ForEach(suggestedTags, id: \.self) { tag in
                                TagPill(
                                    label: tag,
                                    isSelected: selectedTags.contains(tag),
                                    onTap: { toggleTag(tag) }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Quick note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick note (optional)")
                            .font(.headline)
                        TextField("Any observations…", text: $quickNote, axis: .vertical)
                            .lineLimit(3...5)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            .focused($noteFieldFocused)
                    }

                    // Save / skip
                    VStack(spacing: 12) {
                        Button {
                            saveAndDismiss()
                        } label: {
                            Text("Save to journal")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.brewGold, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }

                        Button("Skip") { isPresented = false }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
            .onTapGesture { noteFieldFocused = false }
        }
    }

    // MARK: - Actions

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        journalViewModel.updateFlavourTags(Array(selectedTags), for: session)
    }

    private func saveAndDismiss() {
        if selectedRating > 0 {
            journalViewModel.updateRating(selectedRating, for: session)
        }
        journalViewModel.updateFlavourTags(Array(selectedTags), for: session)
        if !quickNote.isEmpty {
            journalViewModel.updateNotes(quickNote, for: session)
        }
        isPresented = false
    }

    private func ratingLabel(_ rating: Int) -> String {
        ["", "Not great", "It was okay", "Pretty good", "Really good", "Perfect"][rating]
    }
}
```

---

## Step 6 — BrewSessionRowView

Create `Views/Journal/BrewSessionRowView.swift`:

```swift
import SwiftUI

struct BrewSessionRowView: View {
    let session: BrewSession

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Method icon column
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brewGold.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: methodIcon(session.methodName ?? ""))
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brewGold)
                }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.techniqueName ?? "Unknown technique")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    if session.isFavourite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                }

                Text(session.equipmentName ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if session.rating > 0 {
                        RatingStarsView(rating: Int(session.rating), size: 11)
                    }
                    Text(session.brewedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if let tags = session.flavourTags, !tags.isEmpty {
                    let tagList = tags.components(separatedBy: ",").prefix(3)
                    HStack(spacing: 4) {
                        ForEach(Array(tagList), id: \.self) { tag in
                            Text(tag.trimmingCharacters(in: .whitespaces))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brewGold.opacity(0.12),
                                            in: Capsule())
                                .foregroundStyle(Color.brewGold)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func methodIcon(_ method: String) -> String {
        switch method.lowercased() {
        case let m where m.contains("pour over"), let m where m.contains("v60"),
             let m where m.contains("chemex"):    return "drop.fill"
        case let m where m.contains("french"):    return "cup.and.saucer.fill"
        case let m where m.contains("aeropress"): return "arrow.down.circle.fill"
        case let m where m.contains("espresso"):  return "bolt.fill"
        case let m where m.contains("cold"):      return "snowflake"
        case let m where m.contains("moka"):      return "flame.fill"
        default:                                   return "cup.and.saucer"
        }
    }
}
```

---

## Step 7 — BrewJournalView (main history screen)

Create `Views/Journal/BrewJournalView.swift`:

```swift
import SwiftUI
import CoreData

struct BrewJournalView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: BrewJournalViewModel

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: BrewJournalViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Brew Journal")
            .toolbar { toolbarContent }
            .searchable(text: $viewModel.searchText, prompt: "Search techniques, beans…")
            .onChange(of: viewModel.searchText)    { viewModel.fetchSessions() }
            .onChange(of: viewModel.filterRating)  { viewModel.fetchSessions() }
            .onChange(of: viewModel.filterFavourites) { viewModel.fetchSessions() }
            .onChange(of: viewModel.sortOrder)     { viewModel.fetchSessions() }
        }
    }

    // MARK: - Subviews

    private var sessionList: some View {
        List {
            // Stats header
            Section {
                statsHeader
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            // Filter chips
            Section {
                filterChips
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

            // Sessions
            Section {
                ForEach(viewModel.sessions, id: \.objectID) { session in
                    NavigationLink {
                        BrewSessionDetailView(
                            session: session,
                            journalViewModel: viewModel
                        )
                    } label: {
                        BrewSessionRowView(session: session)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.delete(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            viewModel.toggleFavourite(session)
                        } label: {
                            Label(
                                session.isFavourite ? "Unfavourite" : "Favourite",
                                systemImage: session.isFavourite ? "heart.slash" : "heart"
                            )
                        }
                        .tint(.pink)
                    }
                }
            } header: {
                Text("\(viewModel.sessions.count) brew\(viewModel.sessions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(viewModel.totalBrews)",
                label: "Total brews"
            )
            Divider().frame(height: 36)
            statCell(
                value: viewModel.averageRating > 0
                    ? String(format: "%.1f", viewModel.averageRating)
                    : "—",
                label: "Avg rating"
            )
            Divider().frame(height: 36)
            statCell(
                value: viewModel.mostBrewedMethod ?? "—",
                label: "Top method"
            )
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "Favourites",
                    systemImage: "heart.fill",
                    isActive: viewModel.filterFavourites
                ) {
                    viewModel.filterFavourites.toggle()
                }
                ForEach(1...5, id: \.self) { stars in
                    FilterChip(
                        label: "\(stars)★+",
                        isActive: viewModel.filterRating == stars
                    ) {
                        viewModel.filterRating = viewModel.filterRating == stars ? 0 : stars
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundStyle(Color.brewGold.opacity(0.5))
            Text("No brews yet")
                .font(.title3.weight(.semibold))
            Text("Complete a brew to start your journal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(BrewJournalViewModel.SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }
}
```

---

## Step 8 — BrewSessionDetailView

Create `Views/Journal/BrewSessionDetailView.swift`:

```swift
import SwiftUI

struct BrewSessionDetailView: View {
    let session: BrewSession
    @ObservedObject var journalViewModel: BrewJournalViewModel

    @State private var editingNotes = false
    @State private var notesText: String = ""
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Technique header card
                headerCard

                // Rating
                ratingSection

                // Parameters
                parametersSection

                // Flavour tags
                if let tags = session.flavourTags, !tags.isEmpty {
                    flavourTagsSection(tags)
                }

                // Notes
                notesSection

                // Actions
                actionButtons
            }
            .padding(16)
        }
        .navigationTitle(session.brewedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    journalViewModel.toggleFavourite(session)
                } label: {
                    Image(systemName: session.isFavourite ? "heart.fill" : "heart")
                        .foregroundStyle(session.isFavourite ? .pink : .primary)
                }
            }
        }
        .confirmationDialog("Delete this brew?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                journalViewModel.delete(session)
                dismiss()
            }
        }
        .onAppear { notesText = session.notes ?? "" }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        VStack(spacing: 6) {
            Text(session.techniqueName ?? "")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(session.equipmentName ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let bean = session.beanName {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                    Text(bean)
                        .font(.caption)
                }
                .foregroundStyle(Color.brewGold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var ratingSection: some View {
        VStack(spacing: 12) {
            Text("Rating")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            RatingStarsView(
                rating: Int(session.rating),
                size: 32,
                interactive: true,
                onRatingChanged: { journalViewModel.updateRating($0, for: session) }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                paramCell(label: "Coffee", value: String(format: "%.0fg", session.coffeeAmountGrams))
                paramCell(label: "Water", value: String(format: "%.0fml", session.waterAmountMl))
                paramCell(label: "Grind", value: session.grindSize ?? "—")
                paramCell(label: "Temp", value: String(format: "%.0f°C", session.waterTempC))
                paramCell(label: "Servings", value: "\(session.servingSize) cup\(session.servingSize == 1 ? "" : "s")")
                paramCell(label: "Brew time", value: formatTime(Int(session.totalBrewTimeSeconds)))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func paramCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func flavourTagsSection(_ tagsString: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flavour notes")
                .font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(tagsString.components(separatedBy: ","), id: \.self) { tag in
                    Text(tag.trimmingCharacters(in: .whitespaces))
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.brewGold.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.brewGold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Button(editingNotes ? "Done" : "Edit") {
                    if editingNotes {
                        journalViewModel.updateNotes(notesText, for: session)
                    }
                    editingNotes.toggle()
                }
                .font(.subheadline)
                .foregroundStyle(Color.brewGold)
            }
            if editingNotes {
                TextField("Add tasting notes…", text: $notesText, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(12)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Text(session.notes?.isEmpty == false ? session.notes! : "No notes added yet.")
                    .font(.body)
                    .foregroundStyle(session.notes?.isEmpty == false ? .primary : .secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Re-brew button — navigate back to the technique with same params pre-filled
            NavigationLink {
                // Pass session data to route the user back to the technique
                // Implement rebrew navigation based on existing app navigation structure
                Text("Re-brew: \(session.techniqueName ?? "")")
            } label: {
                Label("Brew again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.brewGold, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete brew", systemImage: "trash")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.red)
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }
}
```

---

## Step 9 — Helper views

### FlowLayout (for wrapping tag pills)

Create `Utils/FlowLayout.swift`:

```swift
import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
```

### FilterChip and TagPill

Create `Views/Journal/ChipViews.swift`:

```swift
import SwiftUI

struct FilterChip: View {
    let label: String
    var systemImage: String? = nil
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isActive ? Color.brewGold : Color(.secondarySystemBackground),
                in: Capsule()
            )
            .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isActive)
    }
}

struct TagPill: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected ? Color.brewGold : Color(.secondarySystemBackground),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.brewGold : Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}
```

---

## Step 10 — Wire into the brew completion flow

In the existing `BrewSessionViewModel` (or wherever brew completion is handled), after the
last step is marked complete:

```swift
// 1. Create the BrewJournalViewModel (or inject it via environment)
// 2. Call saveSession() to persist the record
let savedSession = journalViewModel.saveSession(
    methodName: currentMethod.name,
    equipmentName: currentEquipment.name,
    techniqueName: currentTechnique.name,
    beanName: selectedBean?.name,
    beanOrigin: selectedBean?.origin,
    roastLevel: selectedBean?.roastLevel,
    servingSize: servingSize,
    coffeeGrams: coffeeAmountGrams,
    waterMl: waterAmountMl,
    grindSize: currentTechnique.grindSizeLabel,
    waterTempC: currentTechnique.waterTempC,
    totalBrewTimeSeconds: elapsedSeconds
)

// 3. Show the post-brew rating sheet
showPostBrewRating = true
// Pass savedSession to PostBrewRatingView via @State or environment
```

In the brew completion `View`:
```swift
.sheet(isPresented: $showPostBrewRating) {
    PostBrewRatingView(
        session: savedSession,
        journalViewModel: journalViewModel,
        isPresented: $showPostBrewRating
    )
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
}
```

---

## Step 11 — Add Journal tab to main navigation

In the root `TabView` or navigation structure, add:

```swift
NavigationLink {
    BrewJournalView(context: managedObjectContext)
} label: {
    Label("Journal", systemImage: "book.closed.fill")
}
// OR as a tab:
BrewJournalView(context: managedObjectContext)
    .tabItem { Label("Journal", systemImage: "book.closed.fill") }
    .tag(TabSelection.journal)
```

---

## Step 12 — Unit tests

Create `Tests/BrewJournalViewModelTests.swift`:

```swift
import XCTest
import CoreData
@testable import BrewGuide

final class BrewJournalViewModelTests: XCTestCase {
    var context: NSManagedObjectContext!
    var sut: BrewJournalViewModel!

    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
        sut = BrewJournalViewModel(context: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        super.tearDown()
    }

    func test_saveSession_persistsRecord() {
        _ = sut.saveSession(
            methodName: "Pour Over", equipmentName: "V60", techniqueName: "Standard",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 2, coffeeGrams: 30, waterMl: 500,
            grindSize: "Medium", waterTempC: 94, totalBrewTimeSeconds: 240
        )
        XCTAssertEqual(sut.sessions.count, 1)
    }

    func test_updateRating_updatesValue() {
        let session = sut.saveSession(
            methodName: "French Press", equipmentName: "French Press", techniqueName: "Hoffmann",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "Coarse", waterTempC: 92, totalBrewTimeSeconds: 480
        )
        sut.updateRating(4, for: session)
        XCTAssertEqual(sut.sessions.first?.rating, 4)
    }

    func test_delete_removesSession() {
        let session = sut.saveSession(
            methodName: "AeroPress", equipmentName: "AeroPress", techniqueName: "Inverted",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 18, waterMl: 200,
            grindSize: "Medium-Fine", waterTempC: 85, totalBrewTimeSeconds: 120
        )
        sut.delete(session)
        XCTAssertTrue(sut.sessions.isEmpty)
    }

    func test_filterFavourites_returnsOnlyFavourites() {
        let s1 = sut.saveSession(
            methodName: "A", equipmentName: "A", techniqueName: "A",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "Medium", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        _ = sut.saveSession(
            methodName: "B", equipmentName: "B", techniqueName: "B",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "Medium", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        sut.toggleFavourite(s1)
        sut.filterFavourites = true
        sut.fetchSessions()
        XCTAssertEqual(sut.sessions.count, 1)
        XCTAssertTrue(sut.sessions.first?.isFavourite == true)
    }

    func test_averageRating_calculatesCorrectly() {
        let s1 = sut.saveSession(methodName: "A", equipmentName: "A", techniqueName: "A",
            beanName: nil, beanOrigin: nil, roastLevel: nil, servingSize: 1,
            coffeeGrams: 15, waterMl: 250, grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200)
        let s2 = sut.saveSession(methodName: "B", equipmentName: "B", techniqueName: "B",
            beanName: nil, beanOrigin: nil, roastLevel: nil, servingSize: 1,
            coffeeGrams: 15, waterMl: 250, grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200)
        sut.updateRating(4, for: s1)
        sut.updateRating(2, for: s2)
        XCTAssertEqual(sut.averageRating, 3.0, accuracy: 0.01)
    }
}
```

---

## Checklist

- [ ] Core Data entity `BrewSession` added to `.xcdatamodeld`
- [ ] `PersistenceController` created and injected in `@main`
- [ ] `BrewJournalViewModel` created with fetch, save, delete, filter, sort
- [ ] `PostBrewRatingView` sheet shown on brew completion
- [ ] `BrewJournalView` list screen with stats header, filter chips, swipe actions
- [ ] `BrewSessionDetailView` with editable rating, notes, flavour tags, re-brew button
- [ ] `FlowLayout`, `FilterChip`, `TagPill`, `RatingStarsView` helper components created
- [ ] Journal entry point added to main navigation (tab or menu)
- [ ] `saveSession()` called from brew completion in `BrewSessionViewModel`
- [ ] `elapsedSeconds` tracked during brew and passed to `saveSession()`
- [ ] Unit tests passing for save, update, delete, filter, average rating
- [ ] Preview provider working with `PersistenceController.preview`
- [ ] Dark mode verified across all new views
- [ ] VoiceOver labels added to `RatingStarsView` interactive stars
