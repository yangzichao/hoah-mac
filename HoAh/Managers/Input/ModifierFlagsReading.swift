import Foundation
import AppKit

/// Seam over `NSEvent.modifierFlags` so the stuck-key watchdog can be tested
/// without relying on a real event tap. The live implementation reads the
/// current global modifier state.
protocol ModifierFlagsReading: Sendable {
    @MainActor func currentModifierFlags() -> NSEvent.ModifierFlags
}

struct LiveModifierFlagsReading: ModifierFlagsReading {
    @MainActor func currentModifierFlags() -> NSEvent.ModifierFlags {
        NSEvent.modifierFlags
    }
}
