import AppKit
import Foundation

public extension LumiInlinePreviewFacade.ModifierFlags {

    /// 跨进程 OptionSet → AppKit `NSEvent.ModifierFlags`，仅做位映射。
    func toAppKit() -> NSEvent.ModifierFlags {
        var result: NSEvent.ModifierFlags = []
        if contains(.capsLock)   { result.insert(.capsLock) }
        if contains(.shift)      { result.insert(.shift) }
        if contains(.control)    { result.insert(.control) }
        if contains(.option)     { result.insert(.option) }
        if contains(.command)    { result.insert(.command) }
        if contains(.function)   { result.insert(.function) }
        if contains(.numericPad) { result.insert(.numericPad) }
        if contains(.help)       { result.insert(.help) }
        return result
    }

    /// AppKit `NSEvent.ModifierFlags` → 跨进程 OptionSet。
    static func fromAppKitImported(_ flags: NSEvent.ModifierFlags) -> Self {
        var result: Self = []
        if flags.contains(.capsLock)   { result.insert(.capsLock) }
        if flags.contains(.shift)      { result.insert(.shift) }
        if flags.contains(.control)    { result.insert(.control) }
        if flags.contains(.option)     { result.insert(.option) }
        if flags.contains(.command)    { result.insert(.command) }
        if flags.contains(.function)   { result.insert(.function) }
        if flags.contains(.numericPad) { result.insert(.numericPad) }
        if flags.contains(.help)       { result.insert(.help) }
        return result
    }
}

public extension LumiInlinePreviewFacade.ScrollWheelEvent.Phase {

    /// AppKit `NSEvent.Phase` → 跨进程 enum。
    static func fromAppKit(_ phase: NSEvent.Phase) -> Self {
        if phase.contains(.began)      { return .began }
        if phase.contains(.changed)    { return .changed }
        if phase.contains(.ended)      { return .ended }
        if phase.contains(.cancelled)  { return .cancelled }
        if phase.contains(.mayBegin)   { return .mayBegin }
        if phase.contains(.stationary) { return .stationary }
        return .none
    }

    func toAppKit() -> NSEvent.Phase {
        switch self {
        case .began:      return .began
        case .changed:    return .changed
        case .ended:      return .ended
        case .cancelled:  return .cancelled
        case .mayBegin:   return .mayBegin
        case .stationary: return .stationary
        case .none:       return []
        }
    }
}
