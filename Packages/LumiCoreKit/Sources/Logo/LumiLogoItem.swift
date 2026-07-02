import Foundation
import SwiftUI

// MARK: - LogoItem

/// 插件贡献的 Logo 项
///
/// 插件通过 ``LumiPlugin/logoItems(context:)`` 返回此类型，
/// 框架会根据 ``order`` 值选出最高优先级的 Logo 用于显示。
///
/// - 每个场景（如 about、statusBar 等）会独立选择最高优先级的 Logo
/// - 如果多个插件贡献相同 id 的项，行为未定义
/// - ``order`` 值越大优先级越高
/// - 可选的 ``overlay`` 视图会叠加在基础 Logo 视图之上
@MainActor
public struct LogoItem: Identifiable, Sendable {
    public let id: String
    let order: Int
    public let makeView: @MainActor (LogoScene) -> AnyView
    public let makeOverlay: (@MainActor (LogoScene) -> AnyView)?

    init<V: View>(
        id: String,
        order: Int,
        @ViewBuilder makeView: @escaping @MainActor (LogoScene) -> V
    ) {
        self.id = id
        self.order = order
        self.makeView = { scene in AnyView(makeView(scene)) }
        self.makeOverlay = nil
    }

    init<V: View, O: View>(
        id: String,
        order: Int,
        @ViewBuilder makeView: @escaping @MainActor (LogoScene) -> V,
        @ViewBuilder makeOverlay: @escaping @MainActor (LogoScene) -> O
    ) {
        self.id = id
        self.order = order
        self.makeView = { scene in AnyView(makeView(scene)) }
        self.makeOverlay = { scene in AnyView(makeOverlay(scene)) }
    }
}
