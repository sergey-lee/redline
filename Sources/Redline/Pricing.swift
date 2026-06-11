import Foundation

/// USD per million tokens.
struct ModelPricing {
    let input: Double
    let output: Double
    let cacheWrite: Double   // 5-minute ephemeral cache write (1.25x input)
    let cacheRead: Double    // ~0.1x input
}

enum Pricing {
    /// Resolve pricing by substring match on the model id, most specific first.
    static func pricing(for model: String) -> ModelPricing {
        let m = model.lowercased()
        if m.contains("fable") {
            return ModelPricing(input: 10, output: 50, cacheWrite: 12.5, cacheRead: 1.0)
        }
        if m.contains("opus-4-1") || m.contains("opus-4-0") || m.contains("opus-4-2025") {
            // Opus 4.1 / 4.0 legacy pricing
            return ModelPricing(input: 15, output: 75, cacheWrite: 18.75, cacheRead: 1.5)
        }
        if m.contains("opus") {
            // Opus 4.5 / 4.6 / 4.7 / 4.8
            return ModelPricing(input: 5, output: 25, cacheWrite: 6.25, cacheRead: 0.5)
        }
        if m.contains("sonnet") {
            return ModelPricing(input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.3)
        }
        if m.contains("haiku-4") {
            return ModelPricing(input: 1, output: 5, cacheWrite: 1.25, cacheRead: 0.1)
        }
        if m.contains("haiku") {
            return ModelPricing(input: 0.8, output: 4, cacheWrite: 1.0, cacheRead: 0.08)
        }
        // Unknown model — assume current Opus-tier pricing.
        return ModelPricing(input: 5, output: 25, cacheWrite: 6.25, cacheRead: 0.5)
    }

    static func cost(model: String, input: Int, output: Int, cacheWrite: Int, cacheRead: Int) -> Double {
        let p = pricing(for: model)
        return (Double(input) * p.input
                + Double(output) * p.output
                + Double(cacheWrite) * p.cacheWrite
                + Double(cacheRead) * p.cacheRead) / 1_000_000
    }

    /// Short display name for a model id, e.g. "claude-opus-4-8" -> "Opus 4.8".
    static func displayName(for model: String) -> String {
        let m = model.lowercased()
        func version(after family: String) -> String {
            guard let range = m.range(of: family + "-") else { return "" }
            let tail = m[range.upperBound...]
            let parts = tail.split(separator: "-").prefix(2).filter { !$0.isEmpty }
            let numeric = parts.filter { $0.first?.isNumber == true && $0.count <= 2 }
            return numeric.joined(separator: ".")
        }
        if m.contains("fable") { let v = version(after: "fable"); return v.isEmpty ? "Fable" : "Fable \(v)" }
        if m.contains("opus") { let v = version(after: "opus"); return v.isEmpty ? "Opus" : "Opus \(v)" }
        if m.contains("sonnet") { let v = version(after: "sonnet"); return v.isEmpty ? "Sonnet" : "Sonnet \(v)" }
        if m.contains("haiku") { let v = version(after: "haiku"); return v.isEmpty ? "Haiku" : "Haiku \(v)" }
        return model
    }
}
