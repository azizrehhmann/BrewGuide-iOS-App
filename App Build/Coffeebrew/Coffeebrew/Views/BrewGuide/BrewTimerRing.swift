import SwiftUI

struct BrewTimerRing: View {
    let progress: Double
    let secondsRemaining: Int
    let totalSeconds: Int
    let isRunning: Bool
    let hasTimer: Bool
    let isPaused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseScale: CGFloat = 1.0
    @State private var checkmarkScale: CGFloat = 0.0

    private var ringColor: Color {
        guard hasTimer else { return .clear }
        let ratio = totalSeconds > 0 ? Double(secondsRemaining) / Double(totalSeconds) : 0
        if ratio > 0.5 { return Constants.Colors.accentGold }
        if ratio > 0.2 { return Color.orange }
        return Color.red.opacity(0.85)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Constants.Colors.primaryColor.opacity(0.06), lineWidth: 6)

            if hasTimer {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isPaused ? .secondary : ringColor)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 1), value: secondsRemaining)

                    Text(isPaused ? "paused" : "remaining")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .scaleEffect(pulseScale)

            } else {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Constants.Colors.accentGold)
                    .scaleEffect(checkmarkScale)
                    .onAppear {
                        if reduceMotion {
                            checkmarkScale = 1.0
                        } else {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                                checkmarkScale = 1.0
                            }
                        }
                    }
                    .onChange(of: hasTimer) { _, _ in
                        checkmarkScale = 0
                        if reduceMotion {
                            checkmarkScale = 1.0
                        } else {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                                checkmarkScale = 1.0
                            }
                        }
                    }

                Text("Manual step")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .offset(y: 30)
            }
        }
        .frame(width: 200, height: 200)
        .onChange(of: secondsRemaining) { _, remaining in
            guard hasTimer, !reduceMotion else { return }
            if remaining <= 5 && remaining > 0 {
                HapticsManager.shared.timerWarning()
                withAnimation(.easeInOut(duration: 0.2).repeatCount(2, autoreverses: true)) {
                    pulseScale = 1.06
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    pulseScale = 1.0
                }
            }
            if remaining == 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    pulseScale = 1.12
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.spring(response: 0.25)) { pulseScale = 1.0 }
                }
            }
        }
    }

    private var formattedTime: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
    }
}
