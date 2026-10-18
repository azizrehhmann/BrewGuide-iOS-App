import SwiftUI

struct KEyebrow: View {
    let text: String
    var color: Color = Constants.Colors.accentGold
    var showDot: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if showDot {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }
            Text(text)
                .font(Constants.Typography.mono(10))
                .foregroundStyle(color)
                .textCase(.uppercase)
                .tracking(1.4)
        }
    }
}
