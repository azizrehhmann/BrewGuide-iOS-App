import SwiftUI

struct KRatingStars: View {
    var rating: Double = 0
    var interactive: Bool = false
    var onRate: ((Int) -> Void)? = nil
    var starSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: Double(i) <= rating ? "star.fill" : (Double(i) - 0.5 <= rating ? "star.leadinghalf.filled" : "star"))
                    .font(.system(size: starSize))
                    .foregroundStyle(Double(i) <= rating || Double(i) - 0.5 <= rating ? Constants.Colors.accentGold : Constants.Colors.primaryColor.opacity(0.2))
                    .onTapGesture {
                        if interactive { onRate?(i) }
                    }
            }
        }
    }
}
