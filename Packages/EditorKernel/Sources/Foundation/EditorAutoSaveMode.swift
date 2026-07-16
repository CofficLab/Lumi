import Foundation

/// 自动保存模式，对齐 VS Code 的 `files.autoSave` 配置。
public enum EditorAutoSaveMode: String, Equatable, Sendable, CaseIterable {
    /// 关闭自动保存，仅靠手动 ⌘S 或失焦触发（默认）。
    case off
    /// 输入停顿一段时间后自动保存（防抖，默认 1s）。
    case afterDelay
    /// 编辑器失去焦点时自动保存。
    case onFocusChange
    /// 窗口或 App 失去焦点时自动保存。
    case onWindowChange

    /// 是否在内容变化时需要调度防抖保存。
    public var requiresAfterDelayScheduling: Bool { self == .afterDelay }

    /// 是否响应编辑器失焦。
    public var respondsToFocusChange: Bool {
        self == .onFocusChange || self == .onWindowChange
    }

    /// 是否响应窗口/App 失焦。
    public var respondsToWindowChange: Bool { self == .onWindowChange }

    /// 用户可见的显示名（用于设置 UI）。
    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .afterDelay: return "After Delay"
        case .onFocusChange: return "On Focus Change"
        case .onWindowChange: return "On Window Change"
        }
    }
}
