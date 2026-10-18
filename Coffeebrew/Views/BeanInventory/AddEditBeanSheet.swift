import SwiftUI

struct AddEditBeanSheet: View {
    @ObservedObject var viewModel: BeanInventoryViewModel
    @Binding var isPresented: Bool
    let editingBean: CoffeeBean?
    var prefill: BeanLabelParserService.ParsedBean?

    @State private var name = ""
    @State private var roasterName = ""
    @State private var origin = ""
    @State private var roastLevel = "Medium"
    @State private var totalWeight = "250"
    @State private var roastDate: Date = Date()
    @State private var hasRoastDate = false
    @State private var showScannedBanner = false

    // Flavour profile state
    @State private var selectedFlavours: Set<String> = []
    @State private var customFlavourText = ""

    private let roastLevels = ["Light", "Medium-Light", "Medium", "Medium-Dark", "Dark"]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !roasterName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(totalWeight) ?? 0) > 0
    }

    /// Computed suggested use-by date
    private var suggestedUseBy: Date? {
        guard hasRoastDate else { return nil }
        return BeanInventoryViewModel.suggestedUseByDate(roastDate: roastDate, roastLevel: roastLevel)
    }

    /// Days until the suggested use-by date
    private var daysUntilUseBy: Int? {
        guard let useBy = suggestedUseBy else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: useBy).day
    }

    /// Peak freshness window for the selected roast level
    private var peakWindow: (start: Int, end: Int) {
        BeanInventoryViewModel.peakWindow(for: roastLevel)
    }

    /// Days since roast date
    private var daysSinceRoast: Int {
        Calendar.current.dateComponents([.day], from: roastDate, to: Date()).day ?? 0
    }

    /// Builds the comma-separated flavour tag string
    private var flavourTagString: String? {
        let tags = selectedFlavours.sorted()
        return tags.isEmpty ? nil : tags.joined(separator: ",")
    }

    var body: some View {
        NavigationStack {
            Form {
                if showScannedBanner {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scanned from photo")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("Review the details below and fill in anything missing.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Bean Details") {
                    TextField("Bean Name", text: $name)
                    TextField("Roaster", text: $roasterName)
                    TextField("Origin (optional)", text: $origin)
                }

                Section("Roast Level") {
                    Picker("Roast", selection: $roastLevel) {
                        ForEach(roastLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Bag Weight") {
                    HStack {
                        TextField("Weight", text: $totalWeight)
                            .keyboardType(.decimalPad)
                        Text("grams")
                            .foregroundStyle(.secondary)
                    }
                }

                // Flavour Profile Section
                flavourProfileSection

                Section {
                    Toggle("I know the roast date", isOn: $hasRoastDate.animation())

                    if hasRoastDate {
                        DatePicker(
                            "Roast Date",
                            selection: $roastDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)

                        // Freshness info
                        freshnessInfoView
                    }
                } header: {
                    Text("Roast Date & Freshness")
                } footer: {
                    if !hasRoastDate {
                        Text("Adding a roast date enables freshness tracking and use-by suggestions.")
                    }
                }
            }
            .navigationTitle(editingBean != nil ? "Edit Coffee" : (prefill != nil ? "Scanned Coffee" : "Add Coffee"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingBean == nil ? "Add" : "Save") {
                        saveBean()
                        isPresented = false
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let bean = editingBean {
                    name = bean.name ?? ""
                    roasterName = bean.roasterName ?? ""
                    origin = bean.origin ?? ""
                    roastLevel = bean.roastLevel ?? "Medium"
                    totalWeight = String(format: "%.0f", bean.totalWeightGrams)
                    if let rd = bean.roastDate {
                        roastDate = rd
                        hasRoastDate = true
                    }
                    // Load existing flavour tags
                    if let tags = bean.flavourTags, !tags.isEmpty {
                        selectedFlavours = Set(tags.components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty })
                    }
                } else if let scan = prefill {
                    if let n = scan.name { name = n }
                    if let r = scan.roasterName { roasterName = r }
                    if let o = scan.origin { origin = o }
                    if let rl = scan.roastLevel { roastLevel = rl }
                    if let w = scan.weightGrams { totalWeight = String(format: "%.0f", w) }
                    if let rd = scan.roastDate {
                        roastDate = rd
                        hasRoastDate = true
                    }
                    if let tags = scan.tastingNotes, !tags.isEmpty {
                        selectedFlavours = Set(tags)
                    }
                    showScannedBanner = true
                }
            }
        }
    }

    // MARK: - Flavour Profile Section

    private var flavourProfileSection: some View {
        Section {
            // Selected flavours display
            if !selectedFlavours.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selectedFlavours.sorted(), id: \.self) { tag in
                        FlavourChip(label: tag, isSelected: true) {
                            withAnimation(Constants.Animation.standard) {
                                _ = selectedFlavours.remove(tag)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Custom flavour input
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Constants.Colors.accentGold)
                TextField("Add custom flavour...", text: $customFlavourText)
                    .font(.system(.body, design: .rounded))
                    .submitLabel(.done)
                    .onSubmit { addCustomFlavour() }

                if !customFlavourText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        addCustomFlavour()
                    } label: {
                        Text("Add")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(Constants.Colors.accentGold)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Preset categories
            DisclosureGroup {
                ForEach(FlavourPresets.categories, id: \.name) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(category.icon)
                                .font(.system(size: 14))
                            Text(category.name)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }

                        FlowLayout(spacing: 6) {
                            ForEach(category.flavours, id: \.self) { flavour in
                                let isSelected = selectedFlavours.contains(flavour)
                                FlavourChip(label: flavour, isSelected: isSelected) {
                                    withAnimation(Constants.Animation.standard) {
                                        if isSelected {
                                            _ = selectedFlavours.remove(flavour)
                                        } else {
                                            selectedFlavours.insert(flavour)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Constants.Colors.accentGold)
                    Text("Browse Flavour Profiles")
                        .font(.system(.body, design: .rounded))
                }
            }
        } header: {
            Text("Flavour Profile")
        } footer: {
            Text("Tap to add common profiles or type your own.")
        }
    }

    private func addCustomFlavour() {
        let trimmed = customFlavourText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Capitalize first letter
        let formatted = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        withAnimation(Constants.Animation.standard) {
            selectedFlavours.insert(formatted)
        }
        customFlavourText = ""
    }

    // MARK: - Freshness Info

    private var freshnessInfoView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Freshness timeline bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Freshness Timeline")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Day \(daysSinceRoast)")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                FreshnessTimelineBar(
                    daysSinceRoast: daysSinceRoast,
                    totalDays: BeanInventoryViewModel.freshnessWindowDays(for: roastLevel),
                    peakStart: peakWindow.start,
                    peakEnd: peakWindow.end
                )
            }

            // Status label
            HStack(spacing: 6) {
                Circle()
                    .fill(freshnessStatusColor)
                    .frame(width: 8, height: 8)
                Text(freshnessStatusLabel)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(freshnessStatusColor)
            }

            // Suggested use-by date
            if let useBy = suggestedUseBy {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Suggested use by: \(useBy, format: .dateTime.day().month(.abbreviated).year())")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        if let days = daysUntilUseBy {
                            Text(days > 0
                                 ? "\(days) day\(days == 1 ? "" : "s") remaining"
                                 : "Past suggested use-by date")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(days > 7 ? Color.secondary : (days > 0 ? Color.orange : Color.red))
                        }
                    }
                }
            }

            // Peak freshness window hint
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Constants.Colors.accentGold)
                Text("Peak freshness: days \(peakWindow.start)\u{2013}\(peakWindow.end) after roasting")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var freshnessStatusLabel: String {
        if daysSinceRoast < 3 {
            return "Degassing \u{2014} needs time to rest"
        } else if daysSinceRoast < peakWindow.start {
            return "Resting \u{2014} almost ready"
        } else if daysSinceRoast <= peakWindow.end {
            return "Peak Freshness"
        } else if daysSinceRoast <= BeanInventoryViewModel.freshnessWindowDays(for: roastLevel) {
            return "Still Good \u{2014} use soon"
        } else {
            return "Past Prime \u{2014} flavor declining"
        }
    }

    private var freshnessStatusColor: Color {
        if daysSinceRoast < peakWindow.start {
            return .blue
        } else if daysSinceRoast <= peakWindow.end {
            return .green
        } else if daysSinceRoast <= BeanInventoryViewModel.freshnessWindowDays(for: roastLevel) {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Save

    private func saveBean() {
        let weight = Double(totalWeight) ?? 250
        let trimmedOrigin = origin.trimmingCharacters(in: .whitespaces)
        let rd: Date? = hasRoastDate ? roastDate : nil

        if let bean = editingBean {
            viewModel.updateBean(
                bean,
                name: name.trimmingCharacters(in: .whitespaces),
                roasterName: roasterName.trimmingCharacters(in: .whitespaces),
                origin: trimmedOrigin.isEmpty ? nil : trimmedOrigin,
                roastLevel: roastLevel,
                totalWeightGrams: weight,
                roastDate: rd,
                flavourTags: flavourTagString
            )
        } else {
            viewModel.addBean(
                name: name.trimmingCharacters(in: .whitespaces),
                roasterName: roasterName.trimmingCharacters(in: .whitespaces),
                origin: trimmedOrigin.isEmpty ? nil : trimmedOrigin,
                roastLevel: roastLevel,
                totalWeightGrams: weight,
                roastDate: rd,
                flavourTags: flavourTagString
            )
        }
    }
}

// MARK: - Flavour Presets

struct FlavourPresets {
    struct Category {
        let name: String
        let icon: String
        let flavours: [String]
    }

    static let categories: [Category] = [
        Category(name: "Fruity", icon: "\u{1F352}", flavours: [
            "Berry", "Blueberry", "Strawberry", "Raspberry", "Blackberry",
            "Citrus", "Lemon", "Orange", "Grapefruit", "Lime",
            "Stone Fruit", "Peach", "Apricot", "Plum", "Cherry",
            "Tropical", "Mango", "Pineapple", "Passionfruit", "Papaya",
            "Apple", "Grape", "Cranberry"
        ]),
        Category(name: "Sweet", icon: "\u{1F36B}", flavours: [
            "Chocolate", "Dark Chocolate", "Milk Chocolate", "Cocoa",
            "Caramel", "Toffee", "Brown Sugar", "Molasses", "Maple",
            "Honey", "Vanilla", "Butterscotch", "Cane Sugar"
        ]),
        Category(name: "Nutty & Cereal", icon: "\u{1F330}", flavours: [
            "Almond", "Hazelnut", "Walnut", "Peanut", "Cashew",
            "Malt", "Graham Cracker", "Toast", "Cereal", "Oat"
        ]),
        Category(name: "Floral & Herbal", icon: "\u{1F33A}", flavours: [
            "Jasmine", "Rose", "Lavender", "Hibiscus", "Chamomile",
            "Bergamot", "Earl Grey", "Tea-like", "Mint", "Sage",
            "Elderflower"
        ]),
        Category(name: "Spicy & Earthy", icon: "\u{1F33F}", flavours: [
            "Cinnamon", "Clove", "Nutmeg", "Cardamom", "Ginger",
            "Black Pepper", "Tobacco", "Leather", "Cedar", "Woody",
            "Earthy", "Smoky", "Mushroom"
        ]),
        Category(name: "Savoury & Other", icon: "\u{2615}", flavours: [
            "Bright", "Clean", "Crisp", "Juicy", "Winey",
            "Full-bodied", "Creamy", "Silky", "Buttery", "Round",
            "Complex", "Balanced", "Syrupy", "Delicate", "Tangy"
        ]),
    ]

    /// All preset flavour names for quick lookup
    static let allFlavours: Set<String> = {
        Set(categories.flatMap { $0.flavours })
    }()
}

// MARK: - Flavour Chip

struct FlavourChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Constants.Colors.accentGold : Constants.Colors.accentGold.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(isSelected ? ", selected. Double tap to remove" : ". Double tap to add")")
    }
}

// MARK: - Freshness Timeline Bar

struct FreshnessTimelineBar: View {
    let daysSinceRoast: Int
    let totalDays: Int
    let peakStart: Int
    let peakEnd: Int

    private var progress: Double {
        guard totalDays > 0 else { return 0 }
        return min(Double(max(0, daysSinceRoast)) / Double(totalDays), 1.0)
    }

    private var peakStartFraction: Double {
        guard totalDays > 0 else { return 0 }
        return Double(peakStart) / Double(totalDays)
    }

    private var peakEndFraction: Double {
        guard totalDays > 0 else { return 0 }
        return Double(peakEnd) / Double(totalDays)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray5))

                // Peak zone highlight
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.green.opacity(0.2))
                    .frame(width: width * (peakEndFraction - peakStartFraction))
                    .offset(x: width * peakStartFraction)

                // Progress fill with gradient
                RoundedRectangle(cornerRadius: 3)
                    .fill(progressGradient)
                    .frame(width: width * progress)

                // Current position indicator
                Circle()
                    .fill(.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .offset(x: max(0, min(width * progress - 4, width - 8)))
            }
        }
        .frame(height: 6)
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .green, .green, .orange, .red],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
