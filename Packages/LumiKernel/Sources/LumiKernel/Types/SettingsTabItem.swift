import Foundation
import SwiftUI

/// 设置标签项
///
/// 插件通过 `kernel.registerSettingsTabItem()` 注册设置侧边栏标签。
@MainActor
public struct SettingsTabItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String

    /// 排序权重,数值越小越靠前。
    /// 由 `BuiltinPluginManager` 在注册时统一赋为贡献该标签的插件 `order`,
    /// 宿主侧边栏据此对全部标签(无论来自哪个插件)做全局稳定排序。
    public var order: Int

    private let contentBuilder: @MainActor @Sendable () -> AnyView

    public init(
        id: String,
        title: String,
        systemImage: String,
        order: Int = 0,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> some View
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.contentBuilder = { AnyView(content()) }
    }

    /// 构建标签内容视图
    public func makeContent() -> AnyView {
        contentBuilder()
    }
}
