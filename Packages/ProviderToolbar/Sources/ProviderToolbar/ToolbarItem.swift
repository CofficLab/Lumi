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

/// 工具栏项的业务分类。
///
/// 分类描述工具栏项属于哪个工作区上下文，而不是贡献它的插件类型。
/// `global` 项在所有工作区中都可见；其他分类由当前工作区按需打开。
public enum ToolbarItemCategory: String, CaseIterable, Hashable, Sendable {
    /// 所有工作区都可显示的工具栏项。
    case global
    /// 对话工作区。
    case chat
    /// 项目工作区。
    case project
    /// 编辑器工作区。
    case editor
    /// 设计工作区。
    case design
    /// 系统工具工作区。
    case system
    /// 通用工作区。
    case general
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
    /// 该项所属的业务分类。
    ///
    /// 默认使用 `.global`，确保未迁移的旧插件行为保持不变。
    public let category: ToolbarItemCategory
    public var order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        placement: ToolbarPlacement = .trailing,
        category: ToolbarItemCategory = .global,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.placement = placement
        self.category = category
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}
