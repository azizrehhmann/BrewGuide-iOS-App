import SwiftUI
import CoreData

struct BeanFirstEntryView: View {
    @StateObject private var viewModel: BeanFirstViewModel
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    let onBrewTechnique: ((Technique) -> Void)?

    init(databaseService: DatabaseService, onBrewTechnique: ((Technique) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: BeanFirstViewModel(databaseService: databaseService))
        self.onBrewTechnique = onBrewTechnique
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .entry:
                entryContent
            case .scanning:
                BeanScannerView(viewModel: viewModel)
            case .scanProcessing:
                processingView
            case .confirmBean(let profile):
                BeanConfirmView(viewModel: viewModel, beanProfile: profile)
            case .loading:
                loadingView
            case .results(let bean):
                BeanRecommendationsView(
                    viewModel: viewModel,
                    beanProfile: bean,
                    onBrewTechnique: { technique in
                        onBrewTechnique?(technique)
                    }
                )
            case .error(let message):
                errorView(message)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    private var navigationTitle: String {
        switch viewModel.state {
        case .entry: return "Bean First"
        case .scanning: return "Scan Bag"
        case .scanProcessing: return "Reading Label"
        case .confirmBean: return "Confirm Bean"
        case .loading: return "Finding Matches"
        case .results: return "Recommendations"
        case .error: return "Error"
        }
    }

    // MARK: - Entry Content

    private var entryContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .foregroundStyle(Constants.Colors.accentGold)

                    Text("Start with your bean")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Constants.Colors.primaryColor)

                    Text("Get AI-powered technique recommendations tailored to your specific coffee bean.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 12)

                if case .available = viewModel.aiAvailability {
                    // Scan card
                    actionCard(
                        icon: "camera.viewfinder",
                        title: "Scan Bag Label",
                        subtitle: "Point your camera at the coffee bag to auto-detect bean details",
                        action: { viewModel.state = .scanning }
                    )

                    dividerRow

                    // Manual entry
                    actionCard(
                        icon: "square.and.pencil",
                        title: "Enter Manually",
                        subtitle: "Type in your bean's details for a recommendation",
                        action: {
                            viewModel.state = .confirmBean(BeanProfile(name: ""))
                        }
                    )
                } else if case .unavailable(let reason) = viewModel.aiAvailability {
                    ContentUnavailableView(
                        "Apple Intelligence Required",
                        systemImage: "brain",
                        description: Text(reason)
                    )
                }

                dividerRow

                // Inventory pick
                inventorySection
            }
            .padding(.vertical)
        }
        .adaptiveBackground()
    }

    // MARK: - Action Card

    private func actionCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                        .fill(Constants.Colors.accentGold.opacity(0.08))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Constants.Colors.accentGold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Constants.Typography.callout)
                        .foregroundStyle(Constants.Colors.primaryColor)

                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.quaternary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.03),
                radius: 10, x: 0, y: 2
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private var dividerRow: some View {
        HStack {
            Rectangle()
                .fill(Constants.Colors.primaryColor.opacity(0.06))
                .frame(height: 1)
            Text("or")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.quaternary)
            Rectangle()
                .fill(Constants.Colors.primaryColor.opacity(0.06))
                .frame(height: 1)
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding + 16)
    }

    // MARK: - Inventory Section

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Constants.Colors.accentGold)
                Text("From Your Pantry")
                    .font(Constants.Typography.callout)
                    .foregroundStyle(Constants.Colors.primaryColor)
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)

            InventoryBeanPicker(context: context) { coffeeBean in
                viewModel.selectInventoryBean(coffeeBean)
            }
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.3)
            Text("Reading bag label...")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .adaptiveBackground()
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.3)
            VStack(spacing: 4) {
                Text("Finding best techniques...")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("On-device AI is analyzing your bean")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .adaptiveBackground()
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Constants.Colors.primaryColor)

            Text(message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                viewModel.reset()
            } label: {
                Text("Try Again")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                            .fill(Constants.Colors.accentGold)
                    )
            }
            Spacer()
        }
        .adaptiveBackground()
    }
}

// MARK: - Inventory Bean Picker

struct InventoryBeanPicker: View {
    @FetchRequest private var beans: FetchedResults<CoffeeBean>
    let onSelect: (CoffeeBean) -> Void

    init(context: NSManagedObjectContext, onSelect: @escaping (CoffeeBean) -> Void) {
        let request: NSFetchRequest<CoffeeBean> = CoffeeBean.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND remainingWeightGrams > 0")
        request.sortDescriptors = [NSSortDescriptor(key: "purchaseDate", ascending: false)]
        _beans = FetchRequest(fetchRequest: request)
        self.onSelect = onSelect
    }

    var body: some View {
        if beans.isEmpty {
            Text("No beans in your pantry yet")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, Constants.Layout.horizontalPadding)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(beans, id: \.objectID) { bean in
                        Button {
                            onSelect(bean)
                            HapticsManager.shared.selection()
                        } label: {
                            VStack(spacing: 8) {
                                BeanProgressRing(
                                    remaining: bean.remainingWeightGrams,
                                    total: bean.totalWeightGrams,
                                    ringSize: 60
                                )

                                Text(bean.name ?? "")
                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                    .foregroundStyle(Constants.Colors.primaryColor)
                                    .lineLimit(1)

                                Text(bean.roasterName ?? "")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            .frame(width: 90)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                                    .fill(Constants.Colors.cardBackground)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
            }
        }
    }
}
