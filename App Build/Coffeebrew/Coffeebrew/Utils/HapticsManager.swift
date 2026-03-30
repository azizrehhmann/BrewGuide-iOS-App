import UIKit

final class HapticsManager {
    static let shared = HapticsManager()

    private var _enabled: Bool = true
    var isEnabled: Bool {
        get { _enabled }
        set { _enabled = newValue }
    }

    private init() {
        _enabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: - Semantic Haptics

    func stepAdvance() {
        impact(style: .medium)
    }

    func stepBack() {
        impact(style: .light)
    }

    func timerComplete() {
        notification(type: .success)
    }

    func timerWarning() {
        guard isEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.prepare()
        g.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { g.impactOccurred() }
    }

    func brewComplete() {
        notification(type: .success)
    }

    func waterStep() {
        guard isEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare()
        g.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            g.impactOccurred(intensity: 1.0)
        }
    }
}
