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

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

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
                searchAndFilterBar

                if sortedBeans.isEmpty {
                    emptyState
                } else {
                    beanGrid
                }
            }
            .padding(.vertical)
        }
        .adaptiveBackground()
        .navigationTitle("Coffee Beans")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.fetchBeans()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    // Scan button
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
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Constants.Colors.accentGold)
                    }
                    .accessibilityLabel("Scan coffee bag")

                    // Manual add button
                    Button {
                        editingBean = nil
                        scannedBean = nil
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Constants.Colors.accentGold)
                    }
                    .accessibilityLabel("Add coffee beans")
                }
            }
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
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
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
                let parsed = BeanLabelParserService.parse(ocrText: ocrText)

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

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Remaining")
                    .font(Constants.Typography.callout)
                    .foregroundStyle(.primary)
                Text("\(viewModel.activeBeanCount) coffee bag\(viewModel.activeBeanCount == 1 ? "" : "s")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
                TextField("Roaster, origin, varietal, taste notes...", text: $searchText)
                    .font(.system(.body, design: .rounded))
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
                    .fill(Constants.Colors.cardBackground)
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
                            .fill(Constants.Colors.cardBackground)
                    )
            }
            .accessibilityLabel("Sort beans")
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private var beanGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(sortedBeans, id: \.objectID) { bean in
                Button {
                    selectedBean = bean
                } label: {
                    BeanInventoryCardView(bean: bean)
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

    private var emptyState: some View {
        VStack(spacing: 20) {
            EmptyStateView(
                icon: "leaf.fill",
                title: searchText.isEmpty ? "No Beans Yet" : "No Results",
                message: searchText.isEmpty
                    ? "Add your first bag of coffee beans."
                    : "No beans match your search."
            )

            if searchText.isEmpty {
                VStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                            Text("Scan Coffee Bag")
                        }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                                .fill(Constants.Colors.accentGold)
                        )
                    }

                    Button {
                        editingBean = nil
                        scannedBean = nil
                        showAddSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add Manually")
                        }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Constants.Colors.accentGold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                                .strokeBorder(Constants.Colors.accentGold.opacity(0.3), lineWidth: 1.5)
                        )
                    }
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
            }
        }
    }
}
