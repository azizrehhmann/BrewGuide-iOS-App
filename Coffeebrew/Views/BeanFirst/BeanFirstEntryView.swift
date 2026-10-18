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
                VStack(alignment: .leading, spacing: 8) {
                    KEyebrow(text: "AI RECOMMENDATIONS")

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Start with")
                            .font(Constants.Typography.display(40))
                            .foregroundStyle(Constants.Colors.primaryColor)
                        Text("your bean.")
                            .font(Constants.Typography.displayItalic(40))
                            .foregroundStyle(Constants.Colors.accentGold)
                    }

                    Text("Get AI-powered technique recommendations tailored to your specific coffee bean.")
                        .font(Constants.Typography.sans(15))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Constants.Layout.horizontalPadding)
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
                        .font(Constants.Typography.display(18))
                        .foregroundStyle(Constants.Colors.primaryColor)

                    Text(subtitle)
                        .font(Constants.Typography.sans(13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? Constants.Shadows.darkBorderColor : .black.opacity(0.04),
                        lineWidth: colorScheme == .dark ? Constants.Shadows.darkBorderWidth : 0.5
                    )
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Constants.Shadows.cardColor,
                radius: Constants.Shadows.cardRadius, x: 0, y: Constants.Shadows.cardY
            )
        }
        .buttonStyle(.scale)
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private var dividerRow: some View {
        HStack {
            Rectangle()
                .fill(Constants.Colors.primaryColor.opacity(0.06))
                .frame(height: 1)
            Text("or pick one")
                .font(Constants.Typography.mono(11))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Constants.Colors.primaryColor.opacity(0.06))
                .frame(height: 1)
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding + 16)
    }

    // MARK: - Inventory Section

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            KSectionHeader(title: "From Your Pantry")
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
                .font(Constants.Typography.sans(16))
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
                    .font(Constants.Typography.sans(16))
                    .foregroundStyle(.secondary)
                Text("On-device AI is analyzing your bean")
                    .font(Constants.Typography.mono(12))
                    .foregroundStyle(.secondary)
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
                .font(Constants.Typography.display(24))
                .foregroundStyle(Constants.Colors.primaryColor)

            Text(message)
                .font(Constants.Typography.sans(15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            KButton(title: "Try Again", variant: .gold) {
                viewModel.reset()
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)
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
                .font(Constants.Typography.sans(13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Constants.Layout.horizontalPadding)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(beans, id: \.objectID) { bean in
                        Button {
                            onSelect(bean)
                            HapticsManager.shared.selection()
                        } label: {
                            let pct = bean.totalWeightGrams > 0
                                ? (bean.remainingWeightGrams / bean.totalWeightGrams) * 100
                                : 0
                            VStack(spacing: 8) {
                                KBeanRing(percent: pct, size: 60)

                                Text(bean.name ?? "")
                                    .font(Constants.Typography.sans(11, weight: .medium))
                                    .foregroundStyle(Constants.Colors.primaryColor)
                                    .lineLimit(1)

                                Text(bean.roasterName ?? "")
                                    .font(Constants.Typography.mono(10))
                                    .foregroundStyle(.secondary)
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
