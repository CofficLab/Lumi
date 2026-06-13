import SwiftUI

/// 插件贡献的 Logo 项
///
/// 插件通过 ``LumiPlugin/logoItems(context:)`` 返回此类型，
/// 框架会根据 ``order`` 值选出最高优先级的 Logo 用于显示。
///
/// - 每个场景（如 about、statusBar 等）会独立选择最高优先级的 Logo
/// - 如果多个插件贡献相同 id 的项，行为未定义
/// - ``order`` 值越大优先级越高
@MainActor
public struct LumiLogoItem: Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let makeView: @MainActor (LogoScene) -> AnyView

    public init<V: View>(
        id: String,
        order: Int,
        @ViewBuilder makeView: @escaping @MainActor (LogoScene) -> V
    ) {
        self.id = id
        self.order = order
        self.makeView = { scene in AnyView(makeView(scene)) }
    }
}
