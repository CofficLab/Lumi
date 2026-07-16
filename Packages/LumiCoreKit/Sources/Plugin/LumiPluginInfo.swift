/// 插件元信息
///
/// 集中描述一个插件的所有静态属性：身份、显示、分类、策略、阶段与图标。
/// 插件作者只需要填写一个 `LumiPluginInfo`，即可让所有协议派生属性自动生效。
public struct LumiPluginInfo: Sendable, Equatable, Codable {
    /// 插件唯一标识符（如 bundle id 形式）
    public let id: String

    /// 插件显示名称（已本地化）
    public let displayName: String

    /// 插件描述（已本地化）
    public let description: String

    /// 排序权重，值越小越靠前
    public let order: Int

    /// 插件分类（用于设置页分组、搜索过滤等）
    public let category: LumiPluginCategory

    /// 启用策略（控制插件是否默认启用、是否可配置等）
    public let policy: LumiPluginPolicy

    /// 开发阶段（用于 UI 上标识插件成熟度）
    public let stage: LumiPluginStage

    /// SF Symbols 图标名称
    public let iconName: String

    public init(
        id: String,
        displayName: String,
        description: String = "",
        order: Int = 1_000,
        category: LumiPluginCategory = .general,
        policy: LumiPluginPolicy = .optIn,
        stage: LumiPluginStage = .beta,
        iconName: String = "puzzlepiece.extension"
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.order = order
        self.category = category
        self.policy = policy
        self.stage = stage
        self.iconName = iconName
    }
}