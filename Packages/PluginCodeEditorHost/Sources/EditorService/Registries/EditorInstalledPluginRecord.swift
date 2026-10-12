import Foundation

/// 已安装编辑器插件的元数据快照（与 `SuperPlugin` 解耦，供 SPM 模块边界使用）。
public struct EditorInstalledPluginRecord: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let order: Int
    public let isConfigurable: Bool

    public init(
        id: String,
        displayName: String,
        description: String,
        order: Int,
        isConfigurable: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.order = order
        self.isConfigurable = isConfigurable
    }
}
