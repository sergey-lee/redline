import AppKit
import CoreGraphics

func deg(_ d: CGFloat) -> CGFloat { d * .pi / 180 }

// Map a 0...1 gauge fraction to an angle: 0 at lower-left (225°), sweeping
// clockwise over the top to 1 at lower-right (-45°). Red zone is the high end.
func angle(_ f: CGFloat) -> CGFloat { deg(225 - 270 * f) }

func drawIcon(_ S: CGFloat) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Content squircle inset (transparent margin like native macOS icons).
    let margin = S * 0.085
    let inner = CGRect(x: margin, y: margin, width: S - 2*margin, height: S - 2*margin)
    let radius = inner.width * 0.2237
    let bg = CGPath(roundedRect: inner, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Soft drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S*0.012), blur: S*0.03,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
    ctx.addPath(bg); ctx.setFillColor(CGColor(red: 0.1, green: 0.09, blue: 0.085, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()

    // Background gradient fill (warm charcoal → near-black).
    ctx.saveGState()
    ctx.addPath(bg); ctx.clip()
    let grad = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 0.20, green: 0.17, blue: 0.16, alpha: 1),
        CGColor(red: 0.08, green: 0.07, blue: 0.065, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: inner.maxY),
                           end: CGPoint(x: 0, y: inner.minY), options: [])
    // Subtle top sheen.
    let sheen = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.06),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: inner.maxY),
                           end: CGPoint(x: 0, y: inner.midY), options: [])
    ctx.restoreGState()

    let c = CGPoint(x: S/2, y: S/2)
    let R = S * 0.265
    let lw = S * 0.072
    ctx.setLineCap(.round)

    // Track arc (full 270°, dim).
    ctx.setLineWidth(lw)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
    ctx.addArc(center: c, radius: R, startAngle: angle(0), endAngle: angle(1), clockwise: true)
    ctx.strokePath()

    // Amber portion (0 → 0.72).
    ctx.setStrokeColor(CGColor(red: 0.97, green: 0.66, blue: 0.20, alpha: 1))
    ctx.addArc(center: c, radius: R, startAngle: angle(0), endAngle: angle(0.72), clockwise: true)
    ctx.strokePath()

    // Red zone (0.72 → 1.0) — the redline, slightly thicker + glow.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: S*0.02, color: CGColor(red: 0.93, green: 0.22, blue: 0.18, alpha: 0.9))
    ctx.setLineWidth(lw * 1.12)
    ctx.setStrokeColor(CGColor(red: 0.92, green: 0.24, blue: 0.20, alpha: 1))
    ctx.addArc(center: c, radius: R, startAngle: angle(0.72), endAngle: angle(1.0), clockwise: true)
    ctx.strokePath()
    ctx.restoreGState()

    // Tick marks at the redline edge.
    ctx.setLineWidth(S * 0.012)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
    for f in stride(from: CGFloat(0.74), through: 1.0, by: 0.065) {
        let a = angle(f)
        let r1 = R + lw*0.62, r2 = R + lw*0.95
        ctx.move(to: CGPoint(x: c.x + cos(a)*r1, y: c.y + sin(a)*r1))
        ctx.addLine(to: CGPoint(x: c.x + cos(a)*r2, y: c.y + sin(a)*r2))
        ctx.strokePath()
    }

    // Needle pointing into the red zone (≈ 0.84).
    let na = angle(0.84)
    let tip = CGPoint(x: c.x + cos(na) * R * 0.92, y: c.y + sin(na) * R * 0.92)
    let baseW = S * 0.028
    let perp = na + deg(90)
    let b1 = CGPoint(x: c.x + cos(perp)*baseW, y: c.y + sin(perp)*baseW)
    let b2 = CGPoint(x: c.x - cos(perp)*baseW, y: c.y - sin(perp)*baseW)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: S*0.015, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
    ctx.beginPath()
    ctx.move(to: tip); ctx.addLine(to: b1); ctx.addLine(to: b2); ctx.closePath()
    ctx.setFillColor(CGColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Center hub.
    let hubR = S * 0.052
    ctx.setFillColor(CGColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: c.x-hubR, y: c.y-hubR, width: hubR*2, height: hubR*2))
    let hubR2 = S * 0.026
    ctx.setFillColor(CGColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: c.x-hubR2, y: c.y-hubR2, width: hubR2*2, height: hubR2*2))

    return ctx.makeImage()!
}

let outDir = CommandLine.arguments[1]
let sizes: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, s) in sizes {
    let img = drawIcon(s)
    let rep = NSBitmapImageRep(cgImage: img)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
// Also a standalone 1024 preview.
let big = drawIcon(1024)
let rep = NSBitmapImageRep(cgImage: big)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/../icon_preview.png"))
print("done")
