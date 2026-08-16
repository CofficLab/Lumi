import Combine
import Foundation
import ProviderLLM

/// LLM Provider 管理器错误（ProviderLLMManager 自有错误，避免改动 ProviderLLM 的错误集）。
public enum LLMProviderManagerError: Error, LocalizedError, Sendable, Equatable {
    /// 注册时供应商声明的 `id` 为空。
    case emptyProviderID
    /// 指定 id 的供应商不存在。
    case providerNotFound(String)
    /// 没有任何已注册供应商（发送链路未配置）。
    case noProviderConfigured

    public var errorDescription: String? {
        switch self {
        case .emptyProviderID:
            return "LLM provider 声明的 id 为空"
        case .providerNotFound(let id):
            return "LLM provider 未注册: \(id)"
        case .noProviderConfigured:
            return "没有已注册的 LLM provider"
        }
    }
}

/// LLM 供应商管理能力（KernelCore 体系）。
///
/// 复刻自旧内核（KernelLumi）`LLMProviderManaging` 的职责，供精简宿主
/// （LumiMinimalApp 等）在 KernelCore 容器中以 Provider 形式使用：
///
/// - **注册表**：LLM Provider 插件在 `onBoot` 中把各自供应商
///   （`ManagedLLMProvider`）注册进来，管理器按 id O(1) 查找、按注册顺序迭代；
/// - **选中持久化**：记录并持久化当前选中的供应商与模型（UserDefaults）；
/// - **路由发送**：管理器自身同时实现 `LLMProviding`，`complete(_:)` 会把请求
///   路由到选中的供应商并用解析出的模型发送——AgentLoop 直接把管理器当作
///   LLM Provider 注入即可，无需感知具体供应商。
///
/// 与旧版不同，本协议不依赖 KernelLumi 类型，也不持有内核引用；选中/注册变化
/// 通过 `@Published`（`ObservableObject`）广播，由 UI 自行订阅。
@MainActor
public protocol LLMProviderManagerProviding: AnyObject, ObservableObject, LLMProviding {

    // MARK: - Registration（LLM Provider 插件调用）

    /// 全部已注册供应商，按注册顺序返回。
    func allProviders() -> [any ManagedLLMProvider]

    /// 按 id 查找供应商；未注册时返回 `nil`。
    func provider(id: String) -> (any ManagedLLMProvider)?

    /// 当前已注册供应商数量（诊断 / 空态 UI）。
    var providerCount: Int { get }

    /// 注册一个供应商。重复注册同一 id 时覆盖实现并保持原顺序。
    /// - Throws: `LLMProviderManagerError.emptyProviderID` — id 为空时。
    func register(_ provider: any ManagedLLMProvider) throws

    /// 注销指定 id 的供应商；若注销的是当前选中项，则回退到第一个供应商。
    func unregister(id: String)

    // MARK: - Selection（UI / 发送链路读取）

    /// 当前选中的供应商 id；未持久化且无任何供应商时为 `nil`。
    var selectedProviderID: String? { get }

    /// 当前选中的模型 id（属于选中供应商）；可能为 `nil`（用默认模型回退）。
    var selectedModel: String? { get }

    /// 指定供应商的模型 id 列表；供应商未注册时返回空数组。
    func models(for providerID: String) -> [String]

    /// 切换选中的供应商与模型（模型可空，表示回退默认模型）。
    /// 供应商不存在时静默忽略（保持现状）。
    func select(providerID: String, model: String?)
}

// MARK: - Default registration

public extension LLMProviderManagerProviding {
    /// 管理器自身作为 `LLMProviding` 的身份标识（区别于具体供应商）。
    static var managerProviderID: String { "llm-provider-manager" }
}
