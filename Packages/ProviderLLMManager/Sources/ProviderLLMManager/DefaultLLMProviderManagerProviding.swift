import Combine
import Foundation
import ProviderLLM

/// 默认 `LLMProviderManagerProviding` 实现。
///
/// 行为对齐旧版 `LLMProviderManager`：
/// - 注册表：`[id: ManagedLLMProvider]` + 顺序数组，O(1) 查找、插入序稳定；
/// - 选中持久化：UserDefaults 记录供应商/模型；启动恢复、失效回退到
///   第一个供应商的默认模型；
/// - 路由发送：`complete(_:)` 解析「选中供应商 + 模型」后转发，未配置时抛
///   `LLMProviderManagerError.noProviderConfigured`。
///
/// 线程模型：`@MainActor`（注册、选中、发送入口均在主线程），选择变化经
/// `@Published` 广播，UI 直接订阅该对象即可。
@MainActor
public final class DefaultLLMProviderManagerProviding: LLMProviderManagerProviding, @preconcurrency LLMProviding, LLMStreamingProviding {

    public var providerID: String { Self.managerProviderID }

    // MARK: - Registry

    private var providers: [String: any ManagedLLMProvider] = [:]
    private var providerOrder: [String] = []

    // MARK: - Selection

    @Published public private(set) var selectedProviderID: String?
    @Published public private(set) var selectedModel: String?

    // MARK: - UserDefaults Keys

    private enum UserDefaultsKeys {
        static let selectedProviderID = "com.coffic.lumi.llmProviderManager.selectedProviderID"
        static let selectedModel = "com.coffic.lumi.llmProviderManager.selectedModel"
    }

    public init() {
        // 启动时恢复持久化的选中；实际生效校验在首次注册后经 ensureValidSelection 完成。
        _selectedProviderID = Published(initialValue: UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedProviderID))
        _selectedModel = Published(initialValue: UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedModel))
    }

    // MARK: - Registration

    public var providerCount: Int { providers.count }

    public func allProviders() -> [any ManagedLLMProvider] {
        providerOrder.compactMap { providers[$0] }
    }

    public func provider(id: String) -> (any ManagedLLMProvider)? {
        providers[id]
    }

    public func register(_ provider: any ManagedLLMProvider) throws {
        let id = provider.providerInfo.id
        guard !id.isEmpty else {
            throw LLMProviderManagerError.emptyProviderID
        }
        let isNew = providers[id] == nil
        if isNew {
            providerOrder.append(id)
        }
        providers[id] = provider
        ensureValidSelection()
    }

    public func unregister(id: String) {
        guard providers.removeValue(forKey: id) != nil else { return }
        providerOrder.removeAll { $0 == id }
        ensureValidSelection()
    }

    // MARK: - Selection

    public func models(for providerID: String) -> [String] {
        providers[providerID]?.providerInfo.modelIDs ?? []
    }

    public func select(providerID: String, model: String?) {
        guard providers[providerID] != nil else { return }
        if selectedProviderID != providerID {
            selectedProviderID = providerID
            UserDefaults.standard.set(providerID, forKey: UserDefaultsKeys.selectedProviderID)
        }
        if selectedModel != model {
            selectedModel = model
            if let model {
                UserDefaults.standard.set(model, forKey: UserDefaultsKeys.selectedModel)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedModel)
            }
        }
    }

    // MARK: - Send（LLMProviding）

    /// 把请求路由到选中的供应商；请求未显式指定模型时补上解析出的模型。
    ///
    /// 解析优先级：请求自带模型 > 选中模型（若属于选中供应商）> 默认模型。
    /// 没有任何已注册供应商时抛 `noProviderConfigured`。
    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        let resolved = try resolveSelected()
        let model = request.model ?? resolved.model
        let routedRequest = LLMRequest(
            conversationID: request.conversationID,
            messages: request.messages,
            model: model
        )
        return try await resolved.provider.complete(routedRequest)
    }

    // MARK: - Send（LLMStreamingProviding）

    /// 流式发送：路由到选中的供应商。供应商实现了 `LLMStreamingProviding` 时
    /// 走流式；否则回退 `complete(_:)`（体验降级但功能可用）。
    public func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        let resolved = try resolveSelected()
        let model = request.model ?? resolved.model
        let routedRequest = LLMRequest(
            conversationID: request.conversationID,
            messages: request.messages,
            model: model
        )
        if let streamingProvider = resolved.provider as? any LLMStreamingProviding {
            return try await streamingProvider.streamComplete(routedRequest, onChunk: onChunk)
        }
        return try await resolved.provider.complete(routedRequest)
    }

    // MARK: - Selection Resolution

    /// 解析当前生效的「供应商 + 模型」。
    ///
    /// 供应商：选中项 > 第一个注册项；模型：选中模型（属于该供应商）>
    /// 默认模型 > 第一个模型。与旧版 `ensureValidSelection` 的语义一致，
    /// 且不会改变持久化状态（纯读取）。
    private func resolveSelected() throws -> (provider: any ManagedLLMProvider, model: String?) {
        let provider: any ManagedLLMProvider
        if let selectedProviderID, let found = providers[selectedProviderID] {
            provider = found
        } else if let firstID = providerOrder.first, let first = providers[firstID] {
            provider = first
        } else {
            throw LLMProviderManagerError.noProviderConfigured
        }

        let info = provider.providerInfo
        let model: String?
        if let selectedModel, info.contains(model: selectedModel) {
            model = selectedModel
        } else if !info.defaultModel.isEmpty {
            model = info.defaultModel
        } else {
            model = info.modelIDs.first
        }
        return (provider, model)
    }

    /// 注册表变化后保证选中态一致：失效的持久化选中回退到第一个供应商；
    /// 模型回退到默认模型。仅在确实变化时写 UserDefaults 并广播。
    private func ensureValidSelection() {
        let resolved = try? resolveSelected()
        guard let resolved else {
            // 没有任何供应商：清空选中态。
            if selectedProviderID != nil || selectedModel != nil {
                selectedProviderID = nil
                selectedModel = nil
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedProviderID)
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedModel)
            }
            return
        }

        let providerID = resolved.provider.providerInfo.id
        let model = resolved.model

        if selectedProviderID != providerID {
            selectedProviderID = providerID
            UserDefaults.standard.set(providerID, forKey: UserDefaultsKeys.selectedProviderID)
        }
        if selectedModel != model {
            selectedModel = model
            if let model {
                UserDefaults.standard.set(model, forKey: UserDefaultsKeys.selectedModel)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedModel)
            }
        }
    }
}
