import SwiftUI

/// The brew screen's live figure: a coffee scale with a glass server and a V60.
/// Static art comes from `figure_brew_back` / `figure_brew_front` (built in Design/figures/brew);
/// the water, the drip and the scale's display are drawn here between and over those layers.
struct BrewScaleFigure: View {
    /// Water poured so far and the recipe's total, in grams
    let pouredGrams: Double
    let totalGrams: Double
    let elapsedSeconds: Int
    /// Seconds left in a timed step; nil shows elapsed time on the display instead
    var stepSecondsLeft: Int? = nil
    /// True while the timer runs on a pour step: shows the drip
    let pouring: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Geometry exported by Design/figures/brew/build.mjs (out/brew-geometry.json), in the art's 340×360 space
    private enum Art {
        static let size = CGSize(width: 340, height: 360)
        static let waterCenter = CGPoint(x: 184.56, y: 210.38)
        static let waterRadii = CGSize(width: 45.75, height: 22.88)
        static let risePerUnit: CGFloat = 1.2737
        static let maxWaterHeight: CGFloat = 56.5
        static let dripTop = CGPoint(x: 184.56, y: 131)
        static let lcd = CGAffineTransform(a: 1.04, b: 0.52, c: -1.04, d: 0.52, tx: 78.896, ty: 234.075)
        static let lcdWidth: CGFloat = 70
    }

    /// The server is full at 120% of the recipe, so a finished brew sits a little under the rim
    private var fill: CGFloat {
        guard totalGrams > 0 else { return 0 }
        return CGFloat(min(1, max(0, pouredGrams / (totalGrams * 1.2))))
    }

    private func clock(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    private var elapsedText: String { clock(elapsedSeconds) }
    private var displayTime: String { stepSecondsLeft.map(clock) ?? elapsedText }

    var body: some View {
        ZStack {
            Image("figure_brew_back").resizable()
            TimelineView(.animation(paused: !pouring || reduceMotion)) { context in
                Canvas { canvas, size in
                    canvas.scaleBy(x: size.width / Art.size.width, y: size.height / Art.size.height)
                    drawWater(in: &canvas, time: context.date.timeIntervalSinceReferenceDate)
                }
            }
            Image("figure_brew_front").resizable()
            Canvas { canvas, size in
                canvas.scaleBy(x: size.width / Art.size.width, y: size.height / Art.size.height)
                canvas.concatenate(Art.lcd)
                let digits = Color(hex: 0xF1C47E)  // backlit LCD amber, the same in both themes
                canvas.draw(Text("\(Int(pouredGrams.rounded())) g").font(.custom("DMMono-Medium", size: 8.4)).foregroundColor(digits), at: CGPoint(x: 1, y: -1.2), anchor: .bottomLeading)
                canvas.draw(Text(displayTime).font(.custom("DMMono-Medium", size: 8.4)).foregroundColor(digits), at: CGPoint(x: Art.lcdWidth - 1, y: -1.2), anchor: .bottomTrailing)
            }
        }
        .aspectRatio(Art.size, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scale")
        .accessibilityValue("\(Int(pouredGrams.rounded())) of \(Int(totalGrams.rounded())) grams poured, "
            + (stepSecondsLeft.map { "\($0) seconds left in this step" } ?? "\(elapsedText) elapsed"))
    }

    private func drawWater(in canvas: inout GraphicsContext, time: TimeInterval) {
        let c = Art.waterCenter
        let r = Art.waterRadii
        let lift = Art.maxWaterHeight * fill * Art.risePerUnit
        let topY = c.y - lift
        let gold = Constants.Colors.accentGold
        if fill > 0 {
            // The water: the lower half of the bottom ellipse joined to the upper half of the surface
            let point = { (angle: Double, y: CGFloat) in
                CGPoint(x: c.x + r.width * CGFloat(cos(angle)), y: y + r.height * CGFloat(sin(angle)))
            }
            let steps = 36
            var body = Path()
            // Screen y points down, so angles 0…π run along the lower half and π…2π along the upper half
            for i in 0...steps { let p = point(Double(i) / Double(steps) * .pi, c.y); i == 0 ? body.move(to: p) : body.addLine(to: p) }
            for i in 0...steps { body.addLine(to: point(.pi + Double(i) / Double(steps) * .pi, topY)) }
            body.closeSubpath()
            canvas.fill(body, with: .color(gold.opacity(0.24)))
            let surface = Path(ellipseIn: CGRect(x: c.x - r.width, y: topY - r.height, width: 2 * r.width, height: 2 * r.height))
            canvas.fill(surface, with: .color(gold.opacity(0.16)))
            canvas.stroke(surface, with: .color(gold), lineWidth: 0.8)
        }
        if pouring {
            // A thin stream from the cone's tip to the surface; dashes run down unless motion is reduced
            var stream = Path()
            stream.move(to: Art.dripTop)
            stream.addLine(to: CGPoint(x: Art.dripTop.x, y: topY))
            let phase = reduceMotion ? 0 : CGFloat(time.truncatingRemainder(dividingBy: 0.5) / 0.5) * -8
            canvas.stroke(stream, with: .color(gold), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [3, 5], dashPhase: phase))
        }
    }
}

#Preview {
    BrewScaleFigure(pouredGrams: 150, totalGrams: 250, elapsedSeconds: 95, pouring: true)
        .padding()
}
