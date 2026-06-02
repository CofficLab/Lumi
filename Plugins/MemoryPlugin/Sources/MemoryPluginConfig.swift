import AgentToolKit
import Foundation
import LumiCoreKit

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

    /// 从 App 侧发送上下文读取当前项目路径。
    public let projectPathProvider: @MainActor @Sendable (SendMessageContext) -> String

    /// 从 App 侧发送上下文读取语言偏好。
    public let languagePreferenceProvider: @MainActor @Sendable (SendMessageContext) -> LanguagePreference

    public init(
        memoryRootURL: URL,
        maxRelevantMemories: Int = 3,
        staleThresholdDays: Int = 7,
        halfLifeDays: Double = 30,
        injectGlobalIndex: Bool = true,
        injectProjectIndex: Bool = true,
        projectPathProvider: @escaping @MainActor @Sendable (SendMessageContext) -> String = { _ in "" },
        languagePreferenceProvider: @escaping @MainActor @Sendable (SendMessageContext) -> LanguagePreference = { _ in .current }
    ) {
        self.memoryRootURL = memoryRootURL
        self.maxRelevantMemories = maxRelevantMemories
        self.staleThresholdDays = staleThresholdDays
        self.halfLifeDays = halfLifeDays
        self.injectGlobalIndex = injectGlobalIndex
        self.injectProjectIndex = injectProjectIndex
        self.projectPathProvider = projectPathProvider
        self.languagePreferenceProvider = languagePreferenceProvider
    }

    /// 默认配置（用于测试）
    public static let `default` = MemoryPluginConfig(
        memoryRootURL: FileManager.default.temporaryDirectory.appendingPathComponent("Memory")
    )
}
