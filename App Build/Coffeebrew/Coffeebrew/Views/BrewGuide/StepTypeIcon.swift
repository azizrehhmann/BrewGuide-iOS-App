import SwiftUI

struct StepTypeIcon: View {
    let stepTitle: String
    let hasTimer: Bool

    @State private var appeared = false

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(Constants.Colors.accentGold)
            .symbolEffect(.bounce, value: appeared)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Constants.Colors.accentGold.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .onAppear { appeared = true }
    }

    private var iconName: String {
        let t = stepTitle.lowercased()
        if t.contains("bloom") || t.contains("pre-infus") { return "drop.circle" }
        if t.contains("pour") || t.contains("add water")  { return "drop.fill" }
        if t.contains("steep") || t.contains("infus") || t.contains("wait") { return "timer" }
        if t.contains("stir") || t.contains("swirl")      { return "arrow.clockwise.circle" }
        if t.contains("press") || t.contains("plunge")    { return "arrow.down.circle.fill" }
        if t.contains("remove") || t.contains("serve")    { return "cup.and.saucer.fill" }
        if t.contains("grind")                             { return "gearshape.fill" }
        if t.contains("rinse") || t.contains("filter")    { return "drop.triangle.fill" }
        if t.contains("flip") || t.contains("invert")     { return "arrow.up.and.down.circle" }
        if t.contains("open") || t.contains("close")      { return "switch.2" }
        return hasTimer ? "timer" : "checkmark.circle"
    }
}
