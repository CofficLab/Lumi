import SwiftUI

/// Rail 底部固定项（由外部注入）。
///
/// 贴在 Rail 内容区的**最底部**，宽度随 Rail 宽度自动伸缩，自身高度固定。
/// 与 `RailSectionItem`（位于标签栏之上的纵向区块）、`RailTabItem`（标签页）语义不同：
/// 底部固定项承载的是**跨标签常驻的状态信息**（账号、套餐、用量等），
/// 切换 Rail 标签时不会随之切换。
///
/// Rail 整体不可见时（没有可见标签），底部固定项随 Rail 一并消失。
@MainActor
public struct RailBottomItem: Identifiable {
    public let id: String
    /// 排序值，越小越靠上。
    public var order: Int
    /// 底部固定项的高度。`nil` 表示使用宿主提供的默认高度。
    public let height: CGFloat?
    /// 视图构造闭包。
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 0,
        height: CGFloat? = nil,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
        self.height = height
        self.makeView = { AnyView(content()) }
    }
}
