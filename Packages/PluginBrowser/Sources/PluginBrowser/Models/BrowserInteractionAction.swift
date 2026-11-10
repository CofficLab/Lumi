import Foundation

/// 浏览器交互动作。
///
/// 每个动作对应页面内一段确定的行为。动作之间共用同一套 ref 解析与
/// stale 诊断，避免每个动作各写一份「元素找不到」的处理。
enum BrowserInteractionAction: String, CaseIterable, Sendable {
    case click
    case dblclick
    case fill
    case type
    case select
    case check
    case uncheck
    case press
    case hover
    case scroll
    case focus

    /// 是否需要目标元素。
    ///
    /// `scroll` 可以作用于整页，因此不带 `element_ref` 时也合法。
    var requiresElement: Bool { self != .scroll }

    /// 是否需要 `text` 参数。
    var requiresText: Bool {
        switch self {
        case .fill, .type, .select, .press: return true
        default: return false
        }
    }

    /// 面向用户的动作名称。
    var displayName: String {
        switch self {
        case .click: return "点击"
        case .dblclick: return "双击"
        case .fill: return "填入"
        case .type: return "输入"
        case .select: return "选择"
        case .check: return "勾选"
        case .uncheck: return "取消勾选"
        case .press: return "按键"
        case .hover: return "悬停"
        case .scroll: return "滚动"
        case .focus: return "聚焦"
        }
    }
}

/// 交互的结果。
struct BrowserInteractionResult: Sendable {
    /// 点击链接时解析出的目标地址；非链接交互为 nil。
    var navigationTarget: URL?
    /// 面向 LLM 的结果说明。
    var message: String
}
