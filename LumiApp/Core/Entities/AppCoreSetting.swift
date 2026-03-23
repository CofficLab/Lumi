import Foundation

/// 应用级通用设置：用于在多次启动之间恢复 UI 行为。
public struct AppCoreSetting: Codable, Equatable {
    public var mode: AppMode
    /// 上次在 `.app` 模式下选中的导航入口 ID
    ///
    /// 对应 `NavigationEntry.id`，用于在下次进入 `.app` 模式时恢复侧边栏高亮。
    public var selectedNavigationId: String?

    public init(mode: AppMode = .agent, selectedNavigationId: String? = nil) {
        self.mode = mode
        self.selectedNavigationId = selectedNavigationId
    }
}

