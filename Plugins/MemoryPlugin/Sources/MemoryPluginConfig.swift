import Foundation

/// Memory Plugin 配置。
///
/// 由 App 层在初始化时注入，提供存储路径等外部依赖。
public struct MemoryPluginConfig: Sendable {
    /// 记忆文件的根目录 URL
    public let memoryRootURL: URL

    /// 每轮对话注入的最大相关记忆数
    public let maxRelevantMemories: Int

    /// 记忆过期阈值（天）
    public let staleThresholdDays: Int

    /// 时效衰减半衰期（天）
    public let halfLifeDays: Double

    /// 是否注入全局索引
    public let injectGlobalIndex: Bool

    /// 是否注入项目索引
    public let injectProjectIndex: Bool

    /// 是否在每次发送给 LLM 前自动检索记忆
    public let autoRecall: Bool

    /// 是否在 Agent turn 结束后自动保存高置信度记忆
    public let autoSave: Bool

    /// 自动注入的最大字符数，避免记忆挤占对话上下文
    public let maxInjectedCharacters: Int

    public init(
        memoryRootURL: URL,
        maxRelevantMemories: Int = 3,
        staleThresholdDays: Int = 7,
        halfLifeDays: Double = 30,
        injectGlobalIndex: Bool = true,
        injectProjectIndex: Bool = true,
        autoRecall: Bool = true,
        autoSave: Bool = true,
        maxInjectedCharacters: Int = 6000
    ) {
        self.memoryRootURL = memoryRootURL
        self.maxRelevantMemories = maxRelevantMemories
        self.staleThresholdDays = staleThresholdDays
        self.halfLifeDays = halfLifeDays
        self.injectGlobalIndex = injectGlobalIndex
        self.injectProjectIndex = injectProjectIndex
        self.autoRecall = autoRecall
        self.autoSave = autoSave
        self.maxInjectedCharacters = max(0, maxInjectedCharacters)
    }

    /// 默认配置（用于测试）
    public static let `default` = MemoryPluginConfig(
        memoryRootURL: FileManager.default.temporaryDirectory.appendingPathComponent("Memory")
    )
}
