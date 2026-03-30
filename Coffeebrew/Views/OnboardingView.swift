import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [(icon: String, title: LocalizedStringKey, description: LocalizedStringKey)] = [
        (
            "cup.and.saucer.fill",
            "Welcome to BrewGuide",
            "Your step-by-step coffee brewing companion. Explore methods from French Press to AeroPress and beyond."
        ),
        (
            "list.number",
            "Guided Brewing",
            "Follow precise, timed steps for each technique. Adaptive timers keep you on track from bloom to pour."
        ),
        (
            "leaf.fill",
            "Bean Pantry",
            "Track your coffee beans, monitor freshness, and see remaining weight at a glance. Coffee is auto-deducted after each brew."
        ),
        (
            "slider.horizontal.3",
            "Your Preferences",
            "Adjust serving size, units, and appearance in Settings. Every brew is tailored to you."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    onboardingPage(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            bottomButton
                .padding(.horizontal, Constants.Layout.horizontalPadding)
                .padding(.bottom, 40)
        }
        .adaptiveBackground()
    }

    private func onboardingPage(_ page: (icon: String, title: LocalizedStringKey, description: LocalizedStringKey)) -> some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundStyle(Constants.Colors.accentGold)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var bottomButton: some View {
        Button {
            if currentPage < pages.count - 1 {
                withAnimation { currentPage += 1 }
            } else {
                hasSeenOnboarding = true
            }
            HapticsManager.shared.impact(style: .light)
        } label: {
            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                        .fill(Constants.Colors.accentGold)
                )
        }
        .accessibilityLabel(currentPage < pages.count - 1 ? "Next page" : "Get started with BrewGuide")
    }
}
