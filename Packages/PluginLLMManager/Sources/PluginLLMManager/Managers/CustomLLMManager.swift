import Combine
import ProviderLLMManager
import Foundation
import KitLLM
import os
import SuperLogKit

/// PluginLLMManager 自研的 `LLMManaging` 实现。
///
/// 独立实现完整的供应商注册表、选中持久化与请求路由，并提供插件化的扩展点：
///
/// - `routingOverride`：自定义「请求 → 供应商」解析（如按会话路由）。返回
///   `(provider, model)` 时优先使用，`nil` 时回退默认（选中项 > 首个注册项）。
@MainActor
public final class CustomLLMManager: LLMManaging, @preconcurrency SuperLLMProvider, LLMStreamingProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-manager", category: "CustomLLMManager")
    public nonisolated static let emoji = "🧭"
    nonisolated static let verbose = true

    public var providerID: String { Self.managerProviderID }
    public var providerInfo: LLMProviderInfo {
        LLMProviderInfo(
            id: Self.managerProviderID,
            displayName: "LLM Manager",
            defaultModel: "",
            models: [],
            isLocal: true
        )
    }

    // MARK: - Registry

    private var providers: [String: any SuperLLMProvider] = [:]
    private var providerOrder: [String] = []

    // MARK: - Selection

    @Published public private(set) var selectedProviderID: String?
    @Published public private(set) var selectedModel: String?

    // MARK: - UserDefaults Keys

    private enum UserDefaultsKeys {
        static let selectedProviderID = "com.coffic.lumi.llmProviderManager.selectedProviderID"
        static let selectedModel = "com.coffic.lumi.llmProviderManager.selectedModel"
    }

    // MARK: - Routing Extension Point

    /// 路由扩展点：自定义「请求 → 供应商」解析；`nil` 时走默认逻辑。
    public var routingOverride: ((LLMRequest) -> (any SuperLLMProvider, String?)?)?

    // MARK: - Init

    public init() {
        // 启动时恢复持久化的选中；实际生效校验在首次注册后经 ensureValidSelection 完成。
        _selectedProviderID = Published(initialValue: UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedProviderID))
        _selectedModel = Published(initialValue: UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedModel))
        if Self.verbose {
            Self.logger.info("\(Self.t)initialized, restored selection: provider=\(self.selectedProviderID ?? "nil", privacy: .public), model=\(self.selectedModel ?? "nil", privacy: .public)")
        }
    }

    // MARK: - Registration

    public var providerCount: Int { providers.count }

    public func allProviders() -> [any SuperLLMProvider] {
        providerOrder.compactMap { providers[$0] }
    }

    public func provider(id: String) -> (any SuperLLMProvider)? {
        providers[id]
    }

    public func register(_ provider: any SuperLLMProvider) throws {
        let id = provider.providerInfo.id
        guard !id.isEmpty else {
            Self.logger.error("\(Self.t)register failed: empty provider id\(self.r("ignored"))")
            throw LLMProviderManagerError.emptyProviderID
        }
        let isNew = providers[id] == nil
        if isNew {
            providerOrder.append(id)
        }
        providers[id] = provider
        if Self.verbose {
            Self.logger.info("\(Self.t)registered provider: \(id, privacy: .public), total=\(self.providers.count)\(isNew ? "" : self.r("replaced existing"))")
        }
        ensureValidSelection()
    }

    public func unregister(id: String) {
        guard providers.removeValue(forKey: id) != nil else {
            if Self.verbose {
                Self.logger.debug("\(Self.t)unregister skipped: \(id, privacy: .public)\(self.r("not registered"))")
            }
            return
        }
        providerOrder.removeAll { $0 == id }
        if Self.verbose {
            Self.logger.info("\(Self.t)unregistered provider: \(id, privacy: .public), total=\(self.providers.count)")
        }
        ensureValidSelection()
    }

    // MARK: - Selection

    public func models(for providerID: String) -> [String] {
        providers[providerID]?.providerInfo.modelIDs ?? []
    }

    public func select(providerID: String, model: String?) {
        guard providers[providerID] != nil else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)select ignored: \(providerID, privacy: .public)\(self.r("not registered"))")
            }
            return
        }
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
        if Self.verbose {
            Self.logger.info("\(Self.t)selected: provider=\(providerID, privacy: .public), model=\(model ?? "nil", privacy: .public)")
        }
    }

    // MARK: - Send（LLMProviding）

    /// 把请求路由到选中的供应商；请求未显式指定模型时补上解析出的模型。
    ///
    /// 解析优先级：routingOverride > 请求自带模型（须属于路由到的供应商）>
    /// 选中模型（若属于选中供应商）> 默认模型。
    /// 没有任何已注册供应商时抛 `noProviderConfigured`。
    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        // 自定义路由优先
        if let (provider, model) = routingOverride?(request) {
            if Self.verbose {
                Self.logger.debug("\(Self.t)custom route complete: conversation=\(request.conversationID.uuidString.prefix(8)), provider=\(provider.providerInfo.id, privacy: .public), model=\(model ?? "nil", privacy: .public)")
            }
            let routed = LLMRequest(
                conversationID: request.conversationID,
                messages: request.messages,
                model: model ?? request.model,
                tools: request.tools,
                reasoningEffort: request.reasoningEffort
            )
            return try await provider.complete(routed)
        }
        // 默认路由
        let resolved = try resolveSelected()
        let model = routedModel(requested: request.model, resolvedProvider: resolved.provider, resolvedModel: resolved.model)
        let routedRequest = LLMRequest(
            conversationID: request.conversationID,
            messages: request.messages,
            model: model,
            tools: request.tools,
            reasoningEffort: request.reasoningEffort
        )
        if Self.verbose {
            Self.logger.debug("\(Self.t)routing complete: conversation=\(request.conversationID.uuidString.prefix(8)), provider=\(resolved.provider.providerInfo.id, privacy: .public), model=\(model ?? "nil", privacy: .public)")
        }
        return try await resolved.provider.complete(routedRequest)
    }

    // MARK: - Send（LLMStreamingProviding）

    /// 流式发送：路由到选中的供应商。供应商实现了 `LLMStreamingProviding` 时
    /// 走流式；否则回退 `complete(_:)`（体验降级但功能可用）。
    public func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        // 自定义路由优先
        if let (provider, model) = routingOverride?(request) {
            if Self.verbose {
                Self.logger.debug("\(Self.t)custom route stream: conversation=\(request.conversationID.uuidString.prefix(8)), provider=\(provider.providerInfo.id, privacy: .public), model=\(model ?? "nil", privacy: .public)")
            }
            let routed = LLMRequest(
                conversationID: request.conversationID,
                messages: request.messages,
                model: model ?? request.model,
                tools: request.tools,
                reasoningEffort: request.reasoningEffort
            )
            if let streamingProvider = provider as? any LLMStreamingProviding {
                return try await streamingProvider.streamComplete(routed, onChunk: onChunk)
            }
            return try await provider.complete(routed)
        }
        // 默认路由
        let resolved = try resolveSelected()
        let model = routedModel(requested: request.model, resolvedProvider: resolved.provider, resolvedModel: resolved.model)
        let routedRequest = LLMRequest(
            conversationID: request.conversationID,
            messages: request.messages,
            model: model,
            tools: request.tools,
            reasoningEffort: request.reasoningEffort
        )
        if let streamingProvider = resolved.provider as? any LLMStreamingProviding {
            if Self.verbose {
                Self.logger.debug("\(Self.t)routing stream: conversation=\(request.conversationID.uuidString.prefix(8)), provider=\(resolved.provider.providerInfo.id, privacy: .public), model=\(model ?? "nil", privacy: .public)")
            }
            return try await streamingProvider.streamComplete(routedRequest, onChunk: onChunk)
        }
        if Self.verbose {
            Self.logger.debug("\(Self.t)provider has no streaming, falling back to complete: provider=\(resolved.provider.providerInfo.id, privacy: .public)")
        }
        return try await resolved.provider.complete(routedRequest)
    }

    // MARK: - Selection Resolution

    /// 解析实际发送的模型：请求自带模型若属于路由到的供应商则沿用；
    /// 否则回退解析出的选中/默认模型（防止会话残留模型与供应商错配，
    /// 如会话 modelName="gpt-5" 而当前供应商是 opencode-go）。
    private func routedModel(
        requested: String?,
        resolvedProvider: any SuperLLMProvider,
        resolvedModel: String?
    ) -> String? {
        if let requested, resolvedProvider.providerInfo.contains(model: requested) {
            return requested
        }
        if Self.verbose {
            Self.logger.warning("\(Self.t)requested model \(requested ?? "nil", privacy: .public) not owned by provider \(resolvedProvider.providerInfo.id, privacy: .public), falling back to \(resolvedModel ?? "nil", privacy: .public)")
        }
        return resolvedModel
    }

    /// 解析当前生效的「供应商 + 模型」。
    ///
    /// 供应商：选中项 > 第一个注册项；模型：选中模型（属于该供应商）>
    /// 默认模型 > 第一个模型。与旧版 `ensureValidSelection` 的语义一致，
    /// 且不会改变持久化状态（纯读取）。
    private func resolveSelected() throws -> (provider: any SuperLLMProvider, model: String?) {
        let provider: any SuperLLMProvider
        if let selectedProviderID, let found = providers[selectedProviderID] {
            provider = found
        } else if let firstID = providerOrder.first, let first = providers[firstID] {
            provider = first
            if Self.verbose {
                Self.logger.warning("\(Self.t)selected provider \(self.selectedProviderID ?? "nil", privacy: .public) unavailable, falling back to first: \(firstID, privacy: .public)")
            }
        } else {
            Self.logger.error("\(Self.t)no provider configured, throwing noProviderConfigured")
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
        if Self.verbose {
            Self.logger.debug("\(Self.t)resolved: provider=\(info.id, privacy: .public), model=\(model ?? "nil", privacy: .public)")
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
                if Self.verbose {
                    Self.logger.warning("\(Self.t)no providers left, cleared selection")
                }
            }
            return
        }
        // 供应商仍有效，但选中模型可能已失效。
        let info = resolved.provider.providerInfo
        let needsProviderUpdate: Bool
        if selectedProviderID != resolved.provider.providerInfo.id {
            needsProviderUpdate = true
        } else if let selectedModel, !info.contains(model: selectedModel) {
            needsProviderUpdate = true
        } else {
            needsProviderUpdate = false
        }
        guard needsProviderUpdate else { return }

        let newProviderID = resolved.provider.providerInfo.id
        let newModel: String? = info.defaultModel.isEmpty ? info.modelIDs.first : info.defaultModel

        var changed = false
        if selectedProviderID != newProviderID {
            selectedProviderID = newProviderID
            UserDefaults.standard.set(newProviderID, forKey: UserDefaultsKeys.selectedProviderID)
            changed = true
        }
        if selectedModel != newModel {
            selectedModel = newModel
            if let newModel {
                UserDefaults.standard.set(newModel, forKey: UserDefaultsKeys.selectedModel)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedModel)
            }
            changed = true
        }
        if changed, Self.verbose {
            Self.logger.info("\(Self.t)selection auto-corrected: provider=\(newProviderID, privacy: .public), model=\(newModel ?? "nil", privacy: .public)")
        }
    }
}
