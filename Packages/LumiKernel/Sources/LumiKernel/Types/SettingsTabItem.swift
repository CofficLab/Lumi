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
    private let contentBuilder: @MainActor @Sendable () -> AnyView

    public init(
        id: String,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> some View
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.contentBuilder = { AnyView(content()) }
    }

    /// 构建标签内容视图
    public func makeContent() -> AnyView {
        contentBuilder()
    }
}
