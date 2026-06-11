import SwiftUI

/// The hero element: a 270° circular gauge ring with the percentage in the
/// center and a caption below. Matches the App Store main view.
struct GaugeRing: View {
    let percent: Double
    let caption: String
    var size: CGFloat = 150
    var lineWidth: CGFloat = 14

    private var fraction: Double { min(max(percent / 100, 0), 1) }
    private var color: Color { Theme.status(percent) }

    var body: some View {
        ZStack {
            // Track (270° sweep, gap at the bottom).
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Theme.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))

            // Value.
            Circle()
                .trim(from: 0, to: 0.75 * fraction)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
                .animation(.easeOut(duration: 0.5), value: fraction)

            VStack(spacing: 2) {
                HStack(alignment: .top, spacing: 1) {
                    Text("\(Int(percent.rounded()))")
                        .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text("%")
                        .font(.system(size: size * 0.13, weight: .semibold, design: .rounded))
                        .foregroundStyle(color)
                        .padding(.top, size * 0.05)
                }
                Text(caption)
                    .font(.system(size: size * 0.072, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.label)
            }
        }
        .frame(width: size, height: size)
    }
}
