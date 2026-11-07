import SwiftUI

// MARK: - Status Bar Placement

/// 状态栏位置
public enum StatusBarPlacement: Sendable {
    /// 左侧
    case leading
    /// 中间
    case center
    /// 右侧
    case trailing
}

// MARK: - Status Bar Item

/// 状态栏项
///
/// 外部通过 `StatusBarProviding.addStatusBarItems(_:)` 注入，
/// 由实现按 `placement` 渲染到状态栏视图（leading / center / trailing）。
/// 插件应在内容可见时用 `AppStatusBarTile` 包裹贡献视图，统一尺寸、间距和悬停样式；
/// 若内容可能隐藏，应在可见分支内创建 tile，避免留下空项。
@MainActor
public struct StatusBarItem: Identifiable {
    public let id: String
    public let title: String
    public let placement: StatusBarPlacement
    public var order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        placement: StatusBarPlacement = .trailing,
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
