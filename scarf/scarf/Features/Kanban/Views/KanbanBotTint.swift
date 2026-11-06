import SwiftUI

/// Deterministic text color for a bot name in the Kanban inspector's
/// markdown preview.
///
/// The same name always yields the same color, on any machine, with no data
/// read from the host — a card's comments name their author by profile id, and
/// that id is all this needs. A name that is not a profile at all (Hermes
/// stamps some non-profile authors, e.g. `desktop`) tints exactly like any
/// other, which is the reason the color is derived rather than looked up.
///
/// The hue comes from the same FNV-1a seed `BotAvatarGenerator` uses, so a
/// bot's name tint and its fallback avatar sit in the same hue family. That
/// avatar color is a FILL (`s 0.55 / b 0.78`) and far too light to read as
/// text on the light surfaces, so this carries its own saturation/brightness
/// pairs instead of reusing it.
///
/// **Contrast.** SwiftUI's `Color(hue:saturation:brightness:)` is HSB, not
/// HSL, so these pairs are stated in HSB and were swept against the real
/// surface values (backgroundPrimary / Secondary / Tertiary, plus the 50%
/// blend the comment wash produces) at all 3600 hue steps:
///
/// | Appearance | Saturation | Brightness | Worst-case contrast |
/// |------------|-----------|------------|---------------------|
/// | Light      | 0.62      | 0.34       | 6.71:1              |
/// | Dark       | 0.45      | 0.92       | 4.85:1              |
///
/// Both clear WCAG AA (4.5:1) at every hue, so no name can land on an
/// unreadable color. Keep that property if these numbers ever move: the
/// guarantee is structural, not a per-name check.
enum KanbanBotTint {

    static func color(for name: String, scheme: ColorScheme) -> Color {
        let hue = Double(hash(of: name) % 360) / 360.0
        switch scheme {
        case .dark:
            return Color(hue: hue, saturation: 0.45, brightness: 0.92)
        default:
            return Color(hue: hue, saturation: 0.62, brightness: 0.34)
        }
    }

    /// FNV-1a over the name's code points, matching
    /// `BotAvatarGenerator`'s seed — including its JS `charCodeAt(0)`
    /// quirk for supplementary-plane scalars (the *high surrogate*, not the
    /// full code point), so the two paths agree for any name, not just the
    /// ASCII profile ids Hermes actually emits.
    private static func hash(of name: String) -> UInt32 {
        var h: UInt32 = 2166136261
        for scalar in name.unicodeScalars {
            let v = scalar.value
            let code = v > 0xFFFF ? 0xD800 + ((v - 0x10000) >> 10) : v
            h ^= code
            h = h &* 16777619
        }
        return h
    }
}
