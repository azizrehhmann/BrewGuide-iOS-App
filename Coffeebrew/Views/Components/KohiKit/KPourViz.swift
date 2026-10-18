import SwiftUI

struct KPourViz: View {
    let current: Double
    let target: Double
    var phase: String = "Poured"

    private var pct: Double { min(1, current / max(1, target)) }

    var body: some View {
        VStack(spacing: 0) {
            // Vessel with water level
            ZStack {
                // Vessel outline
                VesselShape()
                    .stroke(Constants.Colors.primaryColor.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 120, height: 160)

                // Water fill
                VesselShape()
                    .fill(Constants.Colors.accentGold.opacity(0.15))
                    .frame(width: 120, height: 160)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: 140 * pct)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }

                // Water line
                if pct > 0.02 {
                    Rectangle()
                        .fill(Constants.Colors.accentGold.opacity(0.8))
                        .frame(width: 100, height: 2)
                        .offset(y: 70 - 140 * pct)
                }
            }
            .frame(height: 170)

            // Numbers
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.uppercased())
                        .font(Constants.Typography.mono(10))
                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                        .tracking(1)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(current))")
                            .font(Constants.Typography.display(32, weight: .medium))
                            .foregroundStyle(Constants.Colors.primaryColor)
                        Text("g")
                            .font(Constants.Typography.display(14))
                            .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TARGET")
                        .font(Constants.Typography.mono(10))
                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                        .tracking(1)
                    Text("\(Int(target))g")
                        .font(Constants.Typography.display(20))
                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

struct VesselShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let topInset: CGFloat = 0.15 * w
        let bottomInset: CGFloat = 0.2 * w
        path.move(to: CGPoint(x: topInset, y: 0))
        path.addLine(to: CGPoint(x: bottomInset, y: h * 0.9))
        path.addQuadCurve(to: CGPoint(x: w - bottomInset, y: h * 0.9), control: CGPoint(x: w / 2, y: h))
        path.addLine(to: CGPoint(x: w - topInset, y: 0))
        return path
    }
}
