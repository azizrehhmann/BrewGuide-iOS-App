import SwiftUI

struct RatingStarsView: View {
    let rating: Int
    let maxRating: Int = 5
    var size: CGFloat = 24
    var interactive: Bool = false
    var onRatingChanged: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Constants.Colors.accentGold : Color.secondary.opacity(0.4))
                    .onTapGesture {
                        guard interactive else { return }
                        let newRating = star == rating ? 0 : star
                        onRatingChanged?(newRating)
                    }
            }
        }
        .animation(.spring(response: 0.3), value: rating)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rating) of \(maxRating) stars")
        .accessibilityValue(interactive ? "Tap to change rating" : "")
    }
}
