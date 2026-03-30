import SwiftUI

struct BeanInventoryCardView: View {
    let bean: CoffeeBean

    private var freshnessLabel: String? {
        BeanInventoryViewModel.freshnessLabel(for: bean)
    }

    private var freshnessFraction: Double? {
        BeanInventoryViewModel.freshnessFraction(for: bean)
    }

    private var freshnessColor: Color {
        BeanInventoryViewModel.freshnessColor(for: bean)
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            BeanProgressRing(
                remaining: bean.remainingWeightGrams,
                total: bean.totalWeightGrams,
                ringSize: 80
            )

            Text(bean.name ?? "Unnamed")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(bean.roasterName ?? "")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)

            // Freshness indicator — always reserve space for consistent card height
            VStack(spacing: 4) {
                if let fraction = freshnessFraction {
                    // Freshness bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(freshnessColor)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 4)
                } else {
                    // Invisible placeholder bar to reserve space
                    Color.clear.frame(height: 4)
                }

                if let label = freshnessLabel {
                    Text(label)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(freshnessColor)
                        .lineLimit(1)
                } else {
                    // Invisible placeholder label to reserve space
                    Text(" ")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .fill(Constants.Colors.cardBackground)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : .black.opacity(0.03),
            radius: 8, x: 0, y: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view details")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityDescription: String {
        var desc = "\(bean.name ?? ""), \(bean.roasterName ?? ""), \(Int(bean.remainingWeightGrams)) of \(Int(bean.totalWeightGrams)) grams remaining"
        if let label = freshnessLabel {
            desc += ", \(label)"
        }
        return desc
    }
}
