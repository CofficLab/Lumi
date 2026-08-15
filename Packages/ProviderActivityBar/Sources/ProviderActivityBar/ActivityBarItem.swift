import SwiftUI

// MARK: - Activity Bar Item

/// ActivityBar 入口项（由外部注入）。
///
/// 类似 Lumi 的 `ViewContainerItem`：在 ActivityBar 上显示一个图标入口。
/// 点击时由实现回调 `onSelect`；`makeView` 为 nil 时仅显示图标。
@MainActor
public struct ActivityBarItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public var order: Int
    /// 可选的视图内容；nil 表示仅显示图标入口。
    public let makeView: (@MainActor @Sendable () -> AnyView)?

    public init(
        id: String,
        title: String,
        systemImage: String,
        order: Int = 200,
        makeView: (@MainActor @Sendable () -> AnyView)? = nil
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.makeView = makeView
    }

    /// 便捷初始化：带视图内容。
    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}
