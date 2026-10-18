import SwiftUI

struct BeanDetailView: View {
    let bean: CoffeeBean
    @ObservedObject var viewModel: BeanInventoryViewModel
    @Binding var isPresented: Bool
    @State private var showEditSheet = false
    @State private var showDeductSheet = false
    @State private var deductAmount = ""
    @Environment(\.colorScheme) private var colorScheme

    private var freshnessLabel: String? {
        BeanInventoryViewModel.freshnessLabel(for: bean)
    }

    private var freshnessFraction: Double? {
        BeanInventoryViewModel.freshnessFraction(for: bean)
    }

    private var freshnessColor: Color {
        BeanInventoryViewModel.freshnessColor(for: bean)
    }

    private var usedGrams: Double {
        bean.totalWeightGrams - bean.remainingWeightGrams
    }

    private var usagePercentage: Int {
        guard bean.totalWeightGrams > 0 else { return 0 }
        return Int((usedGrams / bean.totalWeightGrams) * 100)
    }

    private var beanPercent: Double {
        guard bean.totalWeightGrams > 0 else { return 0 }
        return (bean.remainingWeightGrams / bean.totalWeightGrams) * 100
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero area
                    heroSection

                    // Info card overlapping hero
                    infoCard
                        .offset(y: -20)

                    VStack(spacing: 20) {
                        // Parameter grid
                        parameterGrid

                        // Freshness section
                        if bean.roastDate != nil {
                            freshnessCard
                        }

                        // Quick actions
                        quickActions
                    }
                    .padding(.top, 4)
                }
            }
            .adaptiveBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Text("Edit")
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                AddEditBeanSheet(
                    viewModel: viewModel,
                    isPresented: $showEditSheet,
                    editingBean: bean
                )
                .presentationDetents([.medium, .large])
            }
            .alert("Deduct Coffee", isPresented: $showDeductSheet) {
                TextField("Grams used", text: $deductAmount)
                    .keyboardType(.decimalPad)
                Button("Deduct") {
                    if let grams = Double(deductAmount), grams > 0 {
                        viewModel.deductWeight(from: bean, grams: grams)
                    }
                    deductAmount = ""
                }
                Button("Cancel", role: .cancel) { deductAmount = "" }
            } message: {
                Text("Enter the amount of coffee used (in grams).")
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Constants.Colors.accentGold.opacity(0.12),
                    Constants.Colors.accentGold.opacity(0.03),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )

            Image(systemName: "leaf.fill")
                .font(.system(size: 120, weight: .ultraLight))
                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.15))
        }
        .frame(height: 320)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                KEyebrow(
                    text: [bean.origin, bean.roastLevel]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " \u{00B7} ")
                        .uppercased()
                )

                Text(bean.name ?? "Unnamed")
                    .font(Constants.Typography.display(34))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .lineLimit(2)

                if let roaster = bean.roasterName, !roaster.isEmpty {
                    Text("by \(roaster)")
                        .font(Constants.Typography.sans(14))
                        .foregroundStyle(.secondary)
                }

                if let tags = bean.flavourTags, !tags.isEmpty {
                    Text("\u{201C}\(tags)\u{201D}")
                        .font(Constants.Typography.displayItalic(16))
                        .foregroundStyle(Constants.Colors.accentGold)
                        .padding(.top, 4)
                }
            }

            Spacer()

            KBeanRing(percent: beanPercent, size: 56)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .fill(Constants.Colors.cardBackground)
        )
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - 3-Column Parameter Grid

    private var parameterGrid: some View {
        let openedDate: String = {
            if let d = bean.purchaseDate {
                return d.formatted(.dateTime.day().month(.abbreviated))
            }
            return "--"
        }()

        return HStack(spacing: 8) {
            parameterCell(label: "BAG SIZE", value: "\(Int(bean.totalWeightGrams))g")
            parameterCell(label: "REMAINING", value: "\(Int(bean.remainingWeightGrams))g")
            parameterCell(label: "OPENED", value: openedDate)
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private func parameterCell(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(Constants.Typography.mono(10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(Constants.Typography.mono(16))
                .foregroundStyle(Constants.Colors.primaryColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Constants.Colors.cardBackground)
        )
    }

    // MARK: - Freshness Card

    private var freshnessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            KEyebrow(text: "FRESHNESS")

            VStack(alignment: .leading, spacing: 14) {
                if let roastDate = bean.roastDate {
                    let daysSinceRoast = Calendar.current.dateComponents([.day], from: roastDate, to: Date()).day ?? 0
                    let totalDays = BeanInventoryViewModel.freshnessWindowDays(for: bean.roastLevel)
                    let peak = BeanInventoryViewModel.peakWindow(for: bean.roastLevel)

                    FreshnessTimelineBar(
                        daysSinceRoast: daysSinceRoast,
                        totalDays: totalDays,
                        peakStart: peak.start,
                        peakEnd: peak.end
                    )

                    HStack {
                        Text("Day \(daysSinceRoast) of \(totalDays)")
                            .font(Constants.Typography.mono(11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let fraction = freshnessFraction {
                            Text("\(Int(fraction * 100))% fresh")
                                .font(Constants.Typography.mono(11))
                                .foregroundStyle(freshnessColor)
                        }
                    }

                    Divider()

                    // Suggested use-by
                    let useBy = BeanInventoryViewModel.suggestedUseByDate(roastDate: roastDate, roastLevel: bean.roastLevel)
                    let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: useBy).day ?? 0

                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 14))
                            .foregroundStyle(Constants.Colors.accentGold)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use by \(useBy.formatted(.dateTime.day().month(.abbreviated).year()))")
                                .font(Constants.Typography.sans(13, weight: .medium))
                                .foregroundStyle(.primary)
                            Text(daysLeft > 0
                                 ? "\(daysLeft) day\(daysLeft == 1 ? "" : "s") remaining"
                                 : "Past suggested use-by date")
                                .font(Constants.Typography.mono(11))
                                .foregroundStyle(daysLeft > 7 ? Color.secondary : (daysLeft > 0 ? Color.orange : Color.red))
                        }
                    }

                    // Peak window
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundStyle(Constants.Colors.accentGold)
                        Text("Peak freshness: days \(peak.start)\u{2013}\(peak.end)")
                            .font(Constants.Typography.mono(11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 10) {
            KButton(title: "Use Coffee", icon: "minus.circle", variant: .gold) {
                showDeductSheet = true
            }

            KButton(title: "Edit Bean", icon: "pencil", variant: .ghost) {
                showEditSheet = true
            }

            if bean.isActive {
                KButton(title: "Mark as Empty", icon: "xmark.circle", variant: .ghost) {
                    viewModel.markEmpty(bean)
                }
            }
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }
}
