import SwiftUI

struct KSectionHeader: View {
    let title: String
    var actionLabel: String = "All"
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Constants.Typography.sans(13, weight: .semibold))
                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionLabel)
                            .font(Constants.Typography.sans(13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Constants.Colors.accentGold)
                }
            }
        }
    }
}
