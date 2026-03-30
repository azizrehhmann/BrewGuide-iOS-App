import SwiftUI

struct VideoThumbnailCard: View {
    let video: TechniqueVideo
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                YouTubePlayerView(youtubeId: video.youtubeId)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                thumbnailButton
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }

    private var thumbnailButton: some View {
        Button { isExpanded = true } label: {
            ZStack {
                AsyncImage(url: video.thumbnailURL) { image in
                    image.resizable().aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            ProgressView()
                                .tint(.secondary)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Play button overlay
                Circle()
                    .fill(.black.opacity(0.65))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                    )

                // Duration badge
                if let dur = video.durationLabel {
                    Text(dur)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(video.title)")
    }
}
