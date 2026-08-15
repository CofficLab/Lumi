import SwiftUI

// MARK: - Menu Bar Item

/// 菜单栏项（由外部注入）。
///
/// 定义宿主在菜单栏（`MenuBarExtra`）中展示的内容：
/// - `MenuBarContentItem`：常驻内容（如 CPU 小图标 / 文本）；
/// - `MenuBarPopupItem`：点击后展开的弹窗内容（如详细图表）。
@MainActor
public struct MenuBarContentItem: Identifiable {
    public let id: String
    public let title: String
    public var order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}

/// 菜单栏弹窗项（点击后展开的详细内容）。
@MainActor
public struct MenuBarPopupItem: Identifiable {
    public let id: String
    public let title: String
    public var order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}
