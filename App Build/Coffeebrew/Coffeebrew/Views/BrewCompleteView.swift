import SwiftUI

struct BrewCompleteView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let technique: Technique

    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showSummary = false
    @State private var showActions = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Constants.Colors.accentGold)
                .scaleEffect(showIcon ? 1.0 : 0.5)
                .opacity(showIcon ? 1.0 : 0.0)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.6),
                    value: showIcon
                )

            VStack(spacing: 8) {
                Text("Brew Complete")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .accessibilityAddTraits(.isHeader)
                    .opacity(showTitle ? 1.0 : 0.0)
                    .offset(y: showTitle ? 0 : 12)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                        value: showTitle
                    )

                Text("Your \(technique.name) is ready to enjoy.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .opacity(showSummary ? 1.0 : 0.0)
                    .offset(y: showSummary ? 0 : 12)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                        value: showSummary
                    )
            }

            Spacer()

            Button {
                appEnvironment.reset()
            } label: {
                Text("Brew Again")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                            .fill(Constants.Colors.accentGold)
                    )
            }
            .accessibilityLabel("Start a new brew")
            .padding(.horizontal)
            .opacity(showActions ? 1.0 : 0.0)
            .offset(y: showActions ? 0 : 16)
            .animation(
                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                value: showActions
            )
        }
        .padding()
        .adaptiveBackground()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if reduceMotion {
                showIcon = true
                showTitle = true
                showSummary = true
                showActions = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showIcon = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showTitle = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showSummary = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { showActions = true }
            }
        }
    }
}
