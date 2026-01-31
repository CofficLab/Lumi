import SwiftUI

/// 导航入口模型，描述侧边栏中的一个导航项
struct NavigationEntry: Identifiable, Hashable {
    /// 唯一标识符
    let id: String

    /// 导航标题
    let title: String

    /// SF Symbol 图标名称
    let icon: String

    /// 内容视图提供者（返回要显示的视图）
    let contentProvider: () -> AnyView

    /// 插件 ID（用于标识来源）
    let pluginId: String

    /// 是否为默认选中的导航项
    let isDefault: Bool

    /// 初始化方法
    init(
        id: String,
        title: String,
        icon: String,
        pluginId: String,
        isDefault: Bool = false,
        contentProvider: @escaping () -> AnyView
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.pluginId = pluginId
        self.isDefault = isDefault
        self.contentProvider = contentProvider
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: NavigationEntry, rhs: NavigationEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Convenience Initializers

extension NavigationEntry {
    /// 创建一个导航入口（使用 SwiftUI View）
    static func create(
        id: String,
        title: String,
        icon: String,
        pluginId: String,
        isDefault: Bool = false,
        @ViewBuilder content: @escaping () -> some View
    ) -> NavigationEntry {
        NavigationEntry(
            id: id,
            title: title,
            icon: icon,
            pluginId: pluginId,
            isDefault: isDefault
        ) {
            AnyView(content())
        }
    }
}
