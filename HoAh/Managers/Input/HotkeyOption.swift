import Foundation
import AppKit
import Carbon

/// Identifies which physical key (or custom shortcut) drives recording.
/// Includes the raw keycode for event-tap matching plus a device-mask helper
/// to distinguish left/right pairs that share a modifier family.
enum HotkeyOption: String, CaseIterable {
    case none = "none"
    case rightOption = "rightOption"
    case leftOption = "leftOption"
    case leftControl = "leftControl"
    case rightControl = "rightControl"
    case fn = "fn"
    case rightCommand = "rightCommand"
    case rightShift = "rightShift"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .none: return NSLocalizedString("None", comment: "")
        case .rightOption: return NSLocalizedString("Right Option (⌥)", comment: "")
        case .leftOption: return NSLocalizedString("Left Option (⌥)", comment: "")
        case .leftControl: return NSLocalizedString("Left Control (⌃)", comment: "")
        case .rightControl: return NSLocalizedString("Right Control (⌃)", comment: "")
        case .fn: return NSLocalizedString("Fn", comment: "")
        case .rightCommand: return NSLocalizedString("Right Command (⌘)", comment: "")
        case .rightShift: return NSLocalizedString("Right Shift (⇧)", comment: "")
        case .custom: return NSLocalizedString("Custom", comment: "")
        }
    }

    var keyCode: CGKeyCode? {
        switch self {
        case .rightOption: return 0x3D
        case .leftOption: return 0x3A
        case .leftControl: return 0x3B
        case .rightControl: return 0x3E
        case .fn: return 0x3F
        case .rightCommand: return 0x36
        case .rightShift: return 0x3C
        case .custom, .none: return nil
        }
    }

    var isModifierKey: Bool {
        return self != .custom && self != .none
    }

    // Device-dependent mask for precise left/right distinction.
    // Bits map to IOKit NX_DEVICE* constants as exposed via NSEvent.modifierFlags.rawValue.
    var deviceMask: UInt? {
        switch self {
        case .leftControl:  return 0x00000001
        case .rightShift:   return 0x00000004
        case .rightCommand: return 0x00000010
        case .leftOption:   return 0x00000020
        case .rightOption:  return 0x00000040
        case .rightControl: return 0x00002000
        case .fn, .custom, .none: return nil
        }
    }

    func isPressed(in flags: NSEvent.ModifierFlags) -> Bool {
        if self == .fn { return flags.contains(.function) }
        guard let mask = deviceMask else { return false }
        return (flags.rawValue & mask) != 0
    }
}
