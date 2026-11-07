import Foundation

/// 设置入口所属的分组。
///
/// macOS 侧用侧边栏平铺入口，不需要分组；iOS 侧用分组列表（Settings.app 风格），
/// 插件通过声明自己的分组，让根页具备可扫读的语义层级。
public struct SettingEntryGroup: Hashable, Sendable, Identifiable {
    /// 分组标识（同一分组内的入口共享）。
    public let id: String
    /// 分组标题（iOS 根页的分组小标题）。
    public let title: String
    /// 分组排序（数值越小越靠前）。
    public var order: Int

    public init(id: String, title: String, order: Int = 100) {
        self.id = id
        self.title = title
        self.order = order
    }
}

/// 未声明分组的入口所归属的兜底分组。
///
/// 排在所有显式分组之后，且不渲染标题（避免出现无意义的空分组标题）。
public enum SettingEntryFallbackGroup {
    public static let id = "__ungrouped__"
}
