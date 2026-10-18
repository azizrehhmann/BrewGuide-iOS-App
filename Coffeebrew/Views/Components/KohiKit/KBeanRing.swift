import SwiftUI

struct KBeanRing: View {
    let percent: Double
    var size: CGFloat = 56
    var showNumber: Bool = true

    private var strokeColor: Color {
        if percent > 60 { return Constants.Colors.accentGold }
        if percent > 25 { return Color(hex: 0xE8851F) }
        return Color(red: 1, green: 0.23, blue: 0.19).opacity(0.85)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Constants.Colors.primaryColor.opacity(0.06), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: percent / 100)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: percent)

            if showNumber {
                Text("\(Int(percent))")
                    .font(Constants.Typography.mono(size * 0.22))
                    .foregroundStyle(Constants.Colors.primaryColor)
            }
        }
        .frame(width: size, height: size)
    }
}
