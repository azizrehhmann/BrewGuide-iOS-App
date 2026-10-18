import SwiftUI

struct KSegmentedProgress: View {
    let total: Int
    let current: Int
    var progress: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Constants.Colors.primaryColor.opacity(0.06))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Constants.Colors.accentGold)
                            .frame(width: geo.size.width * fillAmount(for: i))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    private func fillAmount(for index: Int) -> Double {
        if index < current { return 1.0 }
        if index == current { return progress }
        return 0
    }
}
