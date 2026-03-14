import Foundation
import OSLog
import MagicKit

/// 供应商注册表
///
/// LLM 供应商的注册和管理中心。
/// 负责：
/// - 注册所有支持的 LLM 供应商
/// - 根据 ID 创建供应商实例
/// - 提供供应商信息查询
///
/// ## 架构说明
///
/// ProviderRegistry 采用静态注册方式，
/// 在初始化时注册所有已知的供应商类型。
/// 使用简单工厂模式创建供应商实例。
///
/// ## 支持的供应商
///
/// | ID | 供应商 | 默认模型 |
/// |-----|--------|----------|
/// | "anthropic" | Anthropic (Claude) | claude-sonnet-4-20250514 |
/// | "openai" | OpenAI (GPT) | gpt-4o |
/// | "deepseek" | DeepSeek | deepseek-chat |
/// | "zhipu" | 智谱 AI | glm-4 |
/// | "aliyun" | 阿里云 | qwen-turbo |
class ProviderRegistry: SuperLog, ObservableObject, @unchecked Sendable {
    /// 日志标识符
    nonisolated static let emoji = "📋"
    
    /// 是否启用详细日志
    nonisolated static let verbose = false

    /// 初始化供应商注册表
    ///
    /// 创建新的注册表实例，具体供应商由外部插件通过 `register(...)` 注入。
    init() {
        if Self.verbose {
            os_log("\(self.t) 供应商注册表已初始化")
        }
    }

    // MARK: - Registered Provider Types

    /// 已注册的供应商类型列表
    ///
    /// 按注册顺序存储所有供应商类型。
    private(set) var providerTypes: [any SuperLLMProvider.Type] = []
    
    /// 供应商实例缓存
    ///
    /// 以供应商 ID 为键，缓存已创建的供应商实例。
    /// 避免重复创建相同的供应商实例。
    private var providerInstances: [String: any SuperLLMProvider] = [:]

    // MARK: - Registration

    /// 注册单个供应商类型
    ///
    /// - Parameter providerType: 要注册的供应商类型
    func register<T: SuperLLMProvider>(_ providerType: T.Type) {
        providerTypes.append(providerType)
        if Self.verbose {
            os_log("\(self.t) 已注册供应商：\(providerType.displayName) (ID: \(providerType.id))")
        }
    }

    /// 批量注册供应商类型
    ///
    /// - Parameter providerTypes: 要注册的供应商类型数组
    func register(_ providerTypes: [any SuperLLMProvider.Type]) {
        for type in providerTypes {
            register(type)
        }
    }

    // MARK: - Queries

    /// 根据 ID 查找供应商类型
    ///
    /// - Parameter id: 供应商 ID
    /// - Returns: 供应商类型，如果未找到则返回 nil
    func providerType(forId id: String) -> (any SuperLLMProvider.Type)? {
        for type in providerTypes {
            if type.id == id {
                return type
            }
        }
        return nil
    }

    /// 获取所有已注册供应商的信息
    ///
    /// - Returns: 供应商信息数组，包含 ID、名称、图标、描述、可用模型等
    func allProviders() -> [ProviderInfo] {
        providerTypes.map { type in
            ProviderInfo(
                id: type.id,
                displayName: type.displayName,
                iconName: type.iconName,
                description: type.description,
                availableModels: type.availableModels,
                defaultModel: type.defaultModel
            )
        }
    }

    /// 创建供应商实例
    ///
    /// 根据供应商 ID 创建对应的供应商实例。
    /// 如果已有缓存实例，则返回缓存的实例。
    ///
    /// - Parameter id: 供应商 ID
    /// - Returns: 供应商实例，如果未找到则返回 nil
    func createProvider(id: String) -> (any SuperLLMProvider)? {
        // 优先返回缓存的实例
        if let cached = providerInstances[id] {
            return cached
        }

        // 在已注册类型中查找匹配的供应商
        guard let type = providerTypes.first(where: { $0.id == id }) else {
            os_log(.error, "\(self.t) 未知的供应商 ID: \(id)")
            return nil
        }

        let instance = type.init()
        providerInstances[id] = instance
        return instance
    }
}

// MARK: - Provider Info

/// 供应商信息模型
///
/// 用于在 UI 中显示供应商列表和详情。
struct ProviderInfo: Identifiable, Equatable, Sendable {
    /// 供应商唯一 ID
    let id: String
    
    /// 显示名称
    let displayName: String
    
    /// 图标名称（SF Symbols）
    ///
    /// 用于 UI 显示，与显示名称对应。
    let iconName: String
    
    /// 供应商描述
    let description: String
    
    /// 可用模型列表
    let availableModels: [String]
    
    /// 默认模型
    let defaultModel: String
}

// MARK: - Provider Registration Extension

/// 供应商注册协议
///
/// 允许供应商类型自行注册到注册表。
protocol ProviderRegistrant {
    /// 注册到指定的注册表
    static func register(to registry: ProviderRegistry)
}
