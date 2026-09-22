import Combine
import Foundation

// MARK: - 面板能力（契约 V2，§8）

/// 底部面板种类（中立枚举；对应 Workbench 的 Bottom Panel）。
public enum EditorBottomPanel: Equatable, Hashable, Sendable {
    case problems
    case references
    case searchResults
    case workspaceSymbols
    case callHierarchy
}

/// 底部面板控制：展示/收起与状态观察。
@MainActor
public protocol EditorPanelProviding: AnyObject {
    /// 当前展示中的底部面板（nil 表示收起）。
    var bottomPanel: EditorBottomPanel? { get }

    /// 底部面板变更流；不以 failure 结束，新订阅者先收到当前值（§8.8）。
    var statePublisher: AnyPublisher<EditorBottomPanel?, Never> { get }

    /// 展示某底部面板；传 `nil` 收起当前面板。
    func presentBottomPanel(_ panel: EditorBottomPanel?)
}
