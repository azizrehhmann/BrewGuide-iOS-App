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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero ring
                    heroSection

                    // Quick actions
                    quickActions

                    // Details card
                    detailsCard

                    // Flavour profile
                    if let tags = bean.flavourTags, !tags.isEmpty {
                        flavourProfileCard(tags: tags)
                    }

                    // Freshness section
                    if bean.roastDate != nil {
                        freshnessCard
                    }

                    // Usage stats
                    usageCard
                }
                .padding(.vertical, 16)
            }
            .adaptiveBackground()
            .navigationTitle(bean.name ?? "Bean Details")
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
        VStack(spacing: 16) {
            BeanProgressRing(
                remaining: bean.remainingWeightGrams,
                total: bean.totalWeightGrams,
                ringSize: 140
            )

            VStack(spacing: 4) {
                Text(bean.name ?? "Unnamed")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .multilineTextAlignment(.center)

                if let roaster = bean.roasterName, !roaster.isEmpty {
                    Text(roaster)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // Status badge
            if let label = freshnessLabel {
                HStack(spacing: 6) {
                    Circle()
                        .fill(freshnessColor)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(freshnessColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(freshnessColor.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            actionButton(icon: "minus.circle.fill", label: "Use Coffee", color: Constants.Colors.accentGold) {
                showDeductSheet = true
            }

            actionButton(icon: "pencil.circle.fill", label: "Edit", color: .blue) {
                showEditSheet = true
            }

            if bean.isActive {
                actionButton(icon: "xmark.circle.fill", label: "Mark Empty", color: .orange) {
                    viewModel.markEmpty(bean)
                }
            }
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Details", icon: "info.circle.fill")

            VStack(spacing: 0) {
                detailRow(label: "Origin", value: bean.origin ?? "Not specified")
                Divider().padding(.horizontal, 16)
                detailRow(label: "Roast Level", value: bean.roastLevel ?? "Medium")
                Divider().padding(.horizontal, 16)
                detailRow(label: "Bag Size", value: "\(Int(bean.totalWeightGrams))g")
                Divider().padding(.horizontal, 16)
                detailRow(label: "Remaining", value: "\(Int(bean.remainingWeightGrams))g")
                if let purchaseDate = bean.purchaseDate {
                    Divider().padding(.horizontal, 16)
                    detailRow(label: "Added", value: purchaseDate.formatted(.dateTime.day().month(.abbreviated).year()))
                }
                if let roastDate = bean.roastDate {
                    Divider().padding(.horizontal, 16)
                    detailRow(label: "Roasted", value: roastDate.formatted(.dateTime.day().month(.abbreviated).year()))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Flavour Profile Card

    private func flavourProfileCard(tags: String) -> some View {
        let flavours = tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Flavour Profile", icon: "drop.halffull")

            FlowLayout(spacing: 8) {
                ForEach(flavours, id: \.self) { flavour in
                    Text(flavour)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(Constants.Colors.accentGold)
                        .background(
                            Capsule()
                                .fill(Constants.Colors.accentGold.opacity(0.12))
                        )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Freshness Card

    private var freshnessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Freshness", icon: "leaf.fill")

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
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let fraction = freshnessFraction {
                            Text("\(Int(fraction * 100))% fresh")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
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
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(.primary)
                            Text(daysLeft > 0
                                 ? "\(daysLeft) day\(daysLeft == 1 ? "" : "s") remaining"
                                 : "Past suggested use-by date")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(daysLeft > 7 ? Color.secondary : (daysLeft > 0 ? Color.orange : Color.red))
                        }
                    }

                    // Peak window
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundStyle(Constants.Colors.accentGold)
                        Text("Peak freshness: days \(peak.start)\u{2013}\(peak.end)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
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

    // MARK: - Usage Card

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Usage", icon: "chart.bar.fill")

            HStack(spacing: 16) {
                usageStat(value: "\(Int(usedGrams))g", label: "Used", color: .orange)
                usageStat(value: "\(Int(bean.remainingWeightGrams))g", label: "Remaining", color: .green)
                usageStat(value: "\(usagePercentage)%", label: "Consumed", color: Constants.Colors.accentGold)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private func usageStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Constants.Colors.accentGold)
            Text(title)
                .font(Constants.Typography.headline)
                .foregroundStyle(Constants.Colors.primaryColor)
        }
        .padding(.bottom, 4)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
