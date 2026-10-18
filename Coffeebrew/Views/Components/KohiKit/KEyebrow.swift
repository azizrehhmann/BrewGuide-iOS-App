import SwiftUI

/// A small label above a heading or value, in sentence case.
struct KEyebrow: View {
    let text: String
    var color: Color = Constants.Colors.accentGold

    var body: some View {
        Text(text)
            .font(Constants.Typography.sans(13, weight: .medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
