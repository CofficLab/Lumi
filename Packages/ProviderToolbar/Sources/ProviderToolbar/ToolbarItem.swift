import SwiftUI

// MARK: - Toolbar Placement

/// 标题栏工具栏位置
public enum ToolbarPlacement: Sendable {
    /// 左侧
    case leading
    /// 中间
    case center
    /// 右侧
    case trailing
}

// MARK: - Toolbar Item

/// 工具栏项
///
/// 外部通过 `ToolbarProviding.registerToolbarItems(_:)` 注入，
/// 由实现按 `placement` 渲染到工具栏视图。
@MainActor
public struct ToolbarItem: Identifiable {
    public let id: String
    public let title: String
    public let placement: ToolbarPlacement
    public var order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        placement: ToolbarPlacement = .trailing,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.placement = placement
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}
