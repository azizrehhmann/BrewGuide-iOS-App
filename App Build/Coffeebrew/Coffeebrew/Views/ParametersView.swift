import SwiftUI
import CoreData

struct ParametersView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.managedObjectContext) private var managedObjectContext
    let technique: Technique
    let selectedBean: Bean?

    @State private var servings: Int = 0
    @State private var showFahrenheit: Bool = false
    @State private var showFluidOunces: Bool = false
    @State private var didLoadDefaults = false
    @State private var inventoryBeans: [CoffeeBean] = []
    @State private var selectedInventoryBean: CoffeeBean?

    // Base values from the first step or technique defaults
    private var baseCoffeeGrams: Double {
        // Use ratio: e.g. for 1:16, 15g coffee -> 250ml water is a standard single cup
        let baseCoffee: Double = 15
        return baseCoffee
    }

    private var coffeeGrams: Double {
        baseCoffeeGrams * Double(servings)
    }

    private var waterGrams: Double {
        coffeeGrams * technique.ratioWaterCoffee
    }

    private var waterVolumeDisplay: String {
        if showFluidOunces {
            let flOz = waterGrams / 29.5735
            return "\(String(format: "%.1f", flOz)) fl oz"
        }
        return "\(Int(waterGrams))ml"
    }

    private var temperatureDisplay: String {
        if showFahrenheit {
            let f = Int(Double(technique.waterTempC) * 9.0 / 5.0 + 32)
            return "\(f)°F"
        }
        return "\(technique.waterTempC)°C"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                servingSizeSection
                parameterCards
                inventoryBeanSection
                recipeInfoSection
                beginBrewButton
            }
            .padding(.vertical)
        }
        .adaptiveBackground()
        .navigationTitle("Parameters")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            guard !didLoadDefaults else { return }
            didLoadDefaults = true
            servings = appEnvironment.defaultServings
            showFahrenheit = appEnvironment.useFahrenheit
            showFluidOunces = appEnvironment.useFluidOunces
            loadInventoryBeans()
        }
    }

    // MARK: - Serving Size

    private var servingSizeSection: some View {
        VStack(spacing: 14) {
            Text("Serving Size")
                .font(Constants.Typography.callout)
                .foregroundStyle(Constants.Colors.primaryColor)

            HStack(spacing: 6) {
                ForEach(1...6, id: \.self) { count in
                    Button {
                        withAnimation(Constants.Animation.spring) {
                            servings = count
                        }
                        HapticsManager.shared.selection()
                    } label: {
                        Text("\(count)")
                            .font(.system(.body, design: .rounded, weight: count == servings ? .bold : .medium))
                            .foregroundStyle(count == servings ? .white : Constants.Colors.primaryColor.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                                    .fill(count == servings ? Constants.Colors.accentGold : Color.clear)
                            )
                    }
                    .accessibilityLabel("\(count) cup\(count > 1 ? "s" : "")")
                    .accessibilityAddTraits(count == servings ? .isSelected : [])
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )

            Text("\(servings) cup\(servings > 1 ? "s" : "")")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Parameter Cards

    private var parameterCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            parameterCard(
                icon: "scalemass.fill",
                label: "Coffee",
                value: "\(String(format: "%.1f", coffeeGrams))g",
                color: Constants.Colors.primaryColor
            )

            Button {
                withAnimation { showFluidOunces.toggle() }
            } label: {
                parameterCardContent(
                    icon: "drop.fill",
                    label: "Water",
                    value: waterVolumeDisplay,
                    color: .blue
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Water \(waterVolumeDisplay). Tap to toggle unit.")

            Button {
                withAnimation { showFahrenheit.toggle() }
            } label: {
                parameterCardContent(
                    icon: "thermometer.medium",
                    label: "Temperature",
                    value: temperatureDisplay,
                    color: .orange
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Temperature \(temperatureDisplay). Tap to toggle unit.")

            NavigationLink {
                GrindDetailView(technique: technique)
            } label: {
                parameterCardContent(
                    icon: "circle.grid.3x3.fill",
                    label: "Grind Size",
                    value: shortGrindLabel,
                    color: .brown
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Grind Size \(shortGrindLabel). Tap for details.")
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private var shortGrindLabel: String {
        let label = technique.grindSizeLabel
        // Trim parenthetical description for the card
        if let parenRange = label.range(of: " (") {
            return String(label[..<parenRange.lowerBound])
        }
        return label
    }

    private func parameterCard(icon: String, label: String, value: String, color: Color) -> some View {
        parameterCardContent(icon: icon, label: label, value: value, color: color)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label): \(value)")
    }

    private func parameterCardContent(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(color.opacity(0.8))

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Constants.Colors.primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .fill(Constants.Colors.cardBackground)
        )
    }

    // MARK: - Recipe Info

    private var recipeInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recipe Summary")
                .font(Constants.Typography.headline)
                .foregroundStyle(Constants.Colors.primaryColor)

            VStack(spacing: 0) {
                recipeRow(label: "Technique", value: technique.name, isFirst: true)
                Divider()
                recipeRow(label: "Brew Ratio", value: "1 : \(String(format: "%.1f", technique.ratioWaterCoffee))")
                Divider()
                recipeRow(label: "Est. Time", value: technique.totalTimeSeconds.formattedTime)
                Divider()
                recipeRow(label: "Steps", value: "\(technique.stepCount)")
                if let bean = selectedBean {
                    Divider()
                    recipeRow(label: "Bean", value: bean.name, isLast: true)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private func recipeRow(label: String, value: String, isFirst: Bool = false, isLast: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(Constants.Typography.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Constants.Typography.body.weight(.medium))
                .foregroundStyle(Constants.Colors.primaryColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Inventory Bean Picker

    @ViewBuilder
    private var inventoryBeanSection: some View {
        if !inventoryBeans.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Use from Pantry")
                    .font(Constants.Typography.headline)
                    .foregroundStyle(Constants.Colors.primaryColor)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // "None" option
                        Button {
                            withAnimation(Constants.Animation.spring) {
                                selectedInventoryBean = nil
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(Color(.secondarySystemGroupedBackground))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "xmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Text("None")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 72)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedInventoryBean == nil
                                        ? Constants.Colors.accentGold.opacity(0.1)
                                        : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        selectedInventoryBean == nil
                                            ? Constants.Colors.accentGold
                                            : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        ForEach(inventoryBeans, id: \.objectID) { bean in
                            Button {
                                withAnimation(Constants.Animation.spring) {
                                    selectedInventoryBean = bean
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    BeanProgressRing(
                                        remaining: bean.remainingWeightGrams,
                                        total: bean.totalWeightGrams,
                                        ringSize: 52
                                    )
                                    Text(bean.name ?? "")
                                        .font(.system(.caption2, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                .frame(width: 72)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedInventoryBean?.objectID == bean.objectID
                                            ? Constants.Colors.accentGold.opacity(0.1)
                                            : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            selectedInventoryBean?.objectID == bean.objectID
                                                ? Constants.Colors.accentGold
                                                : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                if let bean = selectedInventoryBean {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                            .foregroundStyle(Constants.Colors.accentGold)
                        Text("\(String(format: "%.0f", coffeeGrams))g will be deducted from \(bean.name ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)
        }
    }

    private func loadInventoryBeans() {
        let request: NSFetchRequest<CoffeeBean> = CoffeeBean.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND remainingWeightGrams > 0")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CoffeeBean.purchaseDate, ascending: false)]
        inventoryBeans = (try? managedObjectContext.fetch(request)) ?? []
    }

    // MARK: - Begin Brew

    private var beginBrewButton: some View {
        NavigationLink {
            BrewGuideView(technique: technique, coffeeGrams: coffeeGrams, waterGrams: waterGrams)
                .onAppear {
                    appEnvironment.selectedInventoryBeanID = selectedInventoryBean?.id
                }
        } label: {
            Text("Begin Brew")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                        .fill(Constants.Colors.accentGold)
                )
        }
        .accessibilityLabel("Begin brewing")
        .padding(.horizontal, Constants.Layout.horizontalPadding)
        .padding(.top, 8)
    }
}
