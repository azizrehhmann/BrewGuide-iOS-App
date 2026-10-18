import SwiftUI

struct FilterChip: View {
    let label: String
    var systemImage: String? = nil
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isActive ? Constants.Colors.accentGold : Color(.secondarySystemBackground),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
            )
            .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isActive)
    }
}
