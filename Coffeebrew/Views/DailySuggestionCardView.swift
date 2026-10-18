import SwiftUI

struct DailySuggestionCardView: View {
    let suggestion: DailySuggestion
    let onBrewNow: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            todayBadge
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 14)

            Text(suggestion.technique.name)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Constants.Colors.primaryColor)
                .lineLimit(2)
                .padding(.horizontal, 20)

            Text(suggestion.method.name)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 2)

            Text(suggestion.flavourHook)
                .font(.system(.subheadline, design: .rounded).italic())
                .foregroundStyle(Constants.Colors.accentGold)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            statsRow
                .padding(.horizontal, 20)
                .padding(.top, 14)

            if suggestion.hasPreviousBrew || suggestion.streakDays > 0 {
                historyRow
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
            }

            Text(suggestion.reasonLabel)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 10)

            // Deep dive teaser
            if let deepDive = suggestion.technique.deepDive {
                HStack(spacing: 6) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 10, weight: .semibold))
                    Text(deepDive.creator?.name != nil
                         ? "Deep dive by \(deepDive.creator!.name) inside"
                         : "Deep dive available inside")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                }
                .foregroundStyle(Constants.Colors.accentGold.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }

            Button(action: onBrewNow) {
                Text("Brew Now")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Constants.Colors.accentGold)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .elevatedCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's suggestion: \(suggestion.technique.name) using \(suggestion.method.name)")
    }

    // MARK: - Today Badge

    private var todayBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Constants.Colors.accentGold)
                .frame(width: 6, height: 6)

            Text(formattedDate)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Constants.Colors.accentGold)
                .textCase(.uppercase)

            Spacer()

            Image(systemName: "sparkles")
                .font(.caption2)
                .foregroundStyle(Constants.Colors.accentGold.opacity(0.5))
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 16) {
            Label {
                Text(DailySuggestionService.formatTime(suggestion.technique.totalTimeSeconds))
                    .font(.system(.caption, design: .rounded, weight: .medium))
            } icon: {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(Constants.Colors.accentGold)
            }

            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { i in
                    Circle()
                        .fill(i <= suggestion.method.difficulty
                              ? Constants.Colors.accentGold
                              : Constants.Colors.primaryColor.opacity(0.1))
                        .frame(width: 6, height: 6)
                }
            }

            Label {
                Text("\(suggestion.technique.waterTempC)\u{00B0}C")
                    .font(.system(.caption, design: .rounded, weight: .medium))
            } icon: {
                Image(systemName: "thermometer.medium")
                    .font(.caption2)
                    .foregroundStyle(Constants.Colors.accentGold)
            }

            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - History Row

    private var historyRow: some View {
        HStack(spacing: 12) {
            if suggestion.hasPreviousBrew, let rating = suggestion.previousBestRating {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption2)
                    Text("You last made this \u{2014} \(rating)\u{2605}")
                        .font(.system(.caption, design: .rounded))
                }
                .foregroundStyle(.secondary)
            }

            if suggestion.streakDays > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(suggestion.streakDays)-day streak")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()
        }
    }

    // MARK: - Date Formatting

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: suggestion.computedDate)
    }
}
