import SwiftUI

struct BrewSessionRowView: View {
    let session: BrewSession

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Method icon column
            RoundedRectangle(cornerRadius: 10)
                .fill(Constants.Colors.accentGold.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: methodIcon(session.methodName ?? ""))
                        .font(.system(size: 20))
                        .foregroundStyle(Constants.Colors.accentGold)
                }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.techniqueName ?? "Unknown technique")
                        .font(Constants.Typography.display(18))
                        .foregroundStyle(Constants.Colors.primaryColor)
                        .lineLimit(1)
                    Spacer()
                    if session.isFavourite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                }

                Text(session.equipmentName ?? "")
                    .font(Constants.Typography.sans(12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if session.rating > 0 {
                        KRatingStars(rating: Double(session.rating), starSize: 11)
                    }
                    Text(session.brewedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let tags = session.flavourTags, !tags.isEmpty {
                    let tagList = tags.components(separatedBy: ",").prefix(3)
                    HStack(spacing: 4) {
                        ForEach(Array(tagList), id: \.self) { tag in
                            Text(tag.trimmingCharacters(in: .whitespaces))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Constants.Colors.accentGold.opacity(0.12),
                                            in: Capsule())
                                .foregroundStyle(Constants.Colors.accentGold)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func methodIcon(_ method: String) -> String {
        switch method.lowercased() {
        case let m where m.contains("pour over") || m.contains("v60") || m.contains("chemex"):
            return "drop.fill"
        case let m where m.contains("french"):
            return "cup.and.saucer.fill"
        case let m where m.contains("aeropress"):
            return "arrow.down.circle.fill"
        case let m where m.contains("espresso"):
            return "bolt.fill"
        case let m where m.contains("cold"):
            return "snowflake"
        case let m where m.contains("moka") || m.contains("stovetop"):
            return "flame.fill"
        default:
            return "cup.and.saucer"
        }
    }
}
