import SwiftUI

// MARK: - Activity Bar Item

/// ActivityBar 入口项（由外部注入）。
///
/// 仅描述 ActivityBar 上的一个图标入口（id / 标题 / 图标 / 排序），
/// 不关心点击后展示什么内容——内容由其他 Provider（如 ContentViewProviding）负责。
/// 点击行为由 ActivityBar 实现按需回调。
@MainActor
public struct ActivityBarItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public var order: Int
    /// ActivityBar 激活项变化时回调全部已注册项。
    ///
    /// 插件比较传入 id 与自己的 `id`；命中时再激活自己的主内容。
    public let onActiveItemChanged: @MainActor (String?) -> Void

    public init(
        id: String,
        title: String,
        systemImage: String,
        order: Int = 200,
        onActiveItemChanged: @escaping @MainActor (String?) -> Void = { _ in }
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.onActiveItemChanged = onActiveItemChanged
    }
}
