import SwiftUI

struct StepCompletionBurst: View {
    @Binding var trigger: Bool
    let color: Color

    @State private var rings: [BurstRing] = []

    struct BurstRing: Identifiable {
        let id = UUID()
        var scale: CGFloat = 0.3
        var opacity: Double = 0.6
    }

    var body: some View {
        ZStack {
            ForEach(rings) { ring in
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 200, height: 200)
                    .scaleEffect(ring.scale)
                    .opacity(ring.opacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, fired in
            guard fired else { return }
            for delay in [0.0, 0.08, 0.16] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let ring = BurstRing()
                    rings.append(ring)
                    withAnimation(.easeOut(duration: 0.55)) {
                        if let idx = rings.firstIndex(where: { $0.id == ring.id }) {
                            rings[idx].scale = 1.4
                            rings[idx].opacity = 0
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        rings.removeAll { $0.id == ring.id }
                    }
                }
            }
            DispatchQueue.main.async { trigger = false }
        }
    }
}
