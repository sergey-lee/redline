import SwiftUI

/// Liquid Glass helpers. On macOS 26+ they use the real `.glassEffect`; on
/// earlier systems they fall back to a solid themed card so the layout is
/// identical either way.
/// Set during offscreen ImageRenderer snapshots, where live glass can't be
/// composited — forces the solid fallback so previews show the real layout.
enum GlassEnv { @MainActor static var forceSolid = false }

extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 12, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *), !GlassEnv.forceSolid {
            let style: Glass = tint.map { Glass.regular.tint($0.opacity(0.22)) } ?? Glass.regular
            self.glassEffect(style, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tint?.opacity(0.14) ?? Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Theme.track, lineWidth: 1))
            )
        }
    }

    /// Interactive glass for tappable chrome (buttons), with the same fallback.
    @ViewBuilder
    func glassButton(cornerRadius: CGFloat = 8) -> some View {
        if #available(macOS 26.0, *), !GlassEnv.forceSolid {
            self.glassEffect(Glass.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(RoundedRectangle(cornerRadius: cornerRadius).fill(Theme.card))
        }
    }

    /// Groups glass siblings so they blend correctly (macOS 26+); a no-op
    /// passthrough on older systems.
    @ViewBuilder
    func glassGroup() -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) { self }
        } else {
            self
        }
    }
}
