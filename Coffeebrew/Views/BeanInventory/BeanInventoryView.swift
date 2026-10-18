import SwiftUI
import CoreData

// MARK: - Outer Shell (lazy ViewModel creation)

struct BeanInventoryView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var viewModel: BeanInventoryViewModel?

    init(context: NSManagedObjectContext) {
        // Context comes from environment; ViewModel created lazily in onAppear
    }

    var body: some View {
        Group {
            if let viewModel {
                BeanInventoryContentView(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = BeanInventoryViewModel(context: context)
            }
        }
    }
}

// MARK: - Inner Content (proper @ObservedObject observation)

private struct BeanInventoryContentView: View {
    @ObservedObject var viewModel: BeanInventoryViewModel
    @State private var showAddSheet = false
    @State private var editingBean: CoffeeBean?
    @State private var selectedBean: CoffeeBean?
    @State private var beanToDelete: CoffeeBean?
    @State private var showDeleteConfirm = false
    @State private var sortOption: SortOption = .dateAdded
    @State private var searchText = ""

    // Scan-to-add state
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var isProcessingScan = false
    @State private var scanError: String?
    @State private var showScanError = false
    @State private var scannedBean: BeanLabelParserService.ParsedBean?

    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case freshness = "Freshness"
        case remaining = "Weight Left"
        case name = "Name"
    }

    private var sortedBeans: [CoffeeBean] {
        let beans = viewModel.filteredBeans
        switch sortOption {
        case .dateAdded:
            return beans
        case .freshness:
            return beans.sorted { a, b in
                let fa = BeanInventoryViewModel.freshnessFraction(for: a) ?? -1
                let fb = BeanInventoryViewModel.freshnessFraction(for: b) ?? -1
                return fa > fb
            }
        case .remaining:
            return beans.sorted { $0.remainingWeightGrams > $1.remainingWeightGrams }
        case .name:
            return beans.sorted { ($0.name ?? "") < ($1.name ?? "") }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                scanAndAddButtons
                searchAndFilterBar

                if sortedBeans.isEmpty {
                    emptyState
                } else {
                    beanList
                }

                // The empty state already has Scan and Add above; the dashed button is for end of list
                if !sortedBeans.isEmpty { addBeanDashedButton }
            }
            .padding(.vertical)
        }
        .adaptiveBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchBeans()
        }
        .sheet(isPresented: $showAddSheet) {
            AddEditBeanSheet(
                viewModel: viewModel,
                isPresented: $showAddSheet,
                editingBean: editingBean,
                prefill: scannedBean
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedBean) { bean in
            BeanDetailView(
                bean: bean,
                viewModel: viewModel,
                isPresented: Binding(
                    get: { selectedBean != nil },
                    set: { if !$0 { selectedBean = nil } }
                )
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showCamera) {
            ImagePickerView(sourceType: .camera) { image in
                processScannedImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoPicker) {
            ImagePickerView(sourceType: .photoLibrary) { image in
                processScannedImage(image)
            }
        }
        .alert("Delete Bean?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let bean = beanToDelete {
                    viewModel.deleteBean(bean)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this bean from your inventory.")
        }
        .alert("Scan Error", isPresented: $showScanError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scanError ?? "Could not read the coffee bag label. Try again with better lighting.")
        }
        .overlay {
            if isProcessingScan {
                scanningOverlay
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            KEyebrow(text: "\(viewModel.activeBeanCount) BEANS TRACKED")
            Text("Pantry")
                .font(Constants.Typography.display(40))
                .foregroundStyle(Constants.Colors.primaryColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Scan & Add Buttons

    private var scanAndAddButtons: some View {
        HStack(spacing: 10) {
            Menu {
                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                }
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Scan")
                        .font(Constants.Typography.sans(14, weight: .semibold))
                }
                .foregroundStyle(Constants.Colors.accentGold)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Constants.Colors.accentGold.opacity(0.10))
                )
            }
            .accessibilityLabel("Scan coffee bag")

            Button {
                editingBean = nil
                scannedBean = nil
                showAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add")
                        .font(Constants.Typography.sans(14, weight: .semibold))
                }
                .foregroundStyle(Constants.Colors.primaryColor)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Constants.Colors.primaryColor.opacity(0.06))
                )
            }
            .accessibilityLabel("Add coffee beans")
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Search & Filter

    private var searchAndFilterBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
                TextField("Roaster, origin, varietal, taste notes...", text: $searchText)
                    .font(Constants.Typography.sans(15))
                    .onChange(of: searchText) { _, newValue in
                        viewModel.searchText = newValue
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                    .fill(Constants.Colors.primaryColor.opacity(0.04))
            )

            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(Constants.Animation.standard) {
                            sortOption = option
                        }
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Constants.Colors.accentGold)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                            .fill(Constants.Colors.primaryColor.opacity(0.04))
                    )
            }
            .accessibilityLabel("Sort beans")
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Bean List (VStack of cards)

    private var beanList: some View {
        VStack(spacing: 12) {
            ForEach(sortedBeans, id: \.objectID) { bean in
                Button {
                    selectedBean = bean
                } label: {
                    beanCard(bean)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        selectedBean = bean
                    } label: {
                        Label("View Details", systemImage: "eye")
                    }

                    Button {
                        editingBean = bean
                        scannedBean = nil
                        showAddSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    if let roastDate = bean.roastDate {
                        let useBy = BeanInventoryViewModel.suggestedUseByDate(
                            roastDate: roastDate, roastLevel: bean.roastLevel
                        )
                        Button {} label: {
                            Label(
                                "Use by \(useBy.formatted(.dateTime.day().month(.abbreviated)))",
                                systemImage: "calendar.badge.clock"
                            )
                        }
                        .disabled(true)
                    }

                    Button {
                        viewModel.markEmpty(bean)
                    } label: {
                        Label("Mark as Empty", systemImage: "xmark.circle")
                    }
                    Button(role: .destructive) {
                        beanToDelete = bean
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Bean Card

    private func beanCard(_ bean: CoffeeBean) -> some View {
        let percent = bean.totalWeightGrams > 0
            ? (bean.remainingWeightGrams / bean.totalWeightGrams) * 100
            : 0
        let fraction = BeanInventoryViewModel.freshnessFraction(for: bean)
        let label = BeanInventoryViewModel.freshnessLabel(for: bean)
        let daysAgo: Int? = {
            guard let purchase = bean.purchaseDate else { return nil }
            return Calendar.current.dateComponents([.day], from: purchase, to: Date()).day
        }()

        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                KBeanRing(percent: percent, size: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(bean.name ?? "Unnamed")
                        .font(Constants.Typography.display(20))
                        .foregroundStyle(Constants.Colors.primaryColor)
                        .lineLimit(1)

                    HStack(spacing: 0) {
                        Text(bean.roasterName ?? "Unknown roaster")
                            .font(Constants.Typography.mono(10))
                            .foregroundStyle(.secondary)
                        if let days = daysAgo {
                            Text("  \u{00B7}  OPENED \(days)d AGO")
                                .font(Constants.Typography.mono(10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)

                    if let tags = bean.flavourTags, !tags.isEmpty {
                        Text(tags)
                            .font(Constants.Typography.sans(13))
                            .italic()
                            .foregroundStyle(Constants.Colors.accentGold)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            // Freshness bar
            if let frac = fraction {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Constants.Colors.primaryColor.opacity(0.06))
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(freshnessBarColor(frac))
                                .frame(width: geo.size.width * CGFloat(max(0, min(frac, 1))), height: 3)
                        }
                    }
                    .frame(height: 3)

                    if let lbl = label {
                        HStack {
                            Text(lbl.uppercased())
                                .font(Constants.Typography.mono(10))
                                .foregroundStyle(freshnessBarColor(frac))
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(18)
        .cardStyle()
    }

    private func freshnessBarColor(_ fraction: Double) -> Color {
        if fraction > 0.6 { return Constants.Colors.accentGold }
        if fraction > 0.25 { return .orange }
        return .red
    }

    // MARK: - Dashed Add Bean Button

    private var addBeanDashedButton: some View {
        Button {
            editingBean = nil
            scannedBean = nil
            showAddSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                Text("Add bean")
                    .font(Constants.Typography.sans(14))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    .foregroundStyle(Constants.Colors.primaryColor.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Scanning Overlay

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(Constants.Colors.accentGold)
                Text("Reading coffee bag...")
                    .font(Constants.Typography.sans(15, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    // MARK: - Process Scanned Image

    private func processScannedImage(_ image: UIImage) {
        isProcessingScan = true

        Task {
            do {
                let scanner = BeanScannerService()
                let ocrText = try await scanner.recognizeText(from: image)
                let parsed = await BeanLabelParserService.read(ocrText: ocrText)

                await MainActor.run {
                    isProcessingScan = false
                    scannedBean = parsed
                    editingBean = nil
                    showAddSheet = true
                }
            } catch {
                await MainActor.run {
                    isProcessingScan = false
                    scanError = error.localizedDescription
                    showScanError = true
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            EmptyStateView(
                icon: "leaf.fill",
                title: searchText.isEmpty ? "No Beans Yet" : "No Results",
                message: searchText.isEmpty
                    ? "Add your first bag of coffee beans."
                    : "No beans match your search."
            )
        }
    }
}
