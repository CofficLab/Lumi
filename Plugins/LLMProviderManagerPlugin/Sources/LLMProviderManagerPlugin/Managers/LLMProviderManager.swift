import Foundation
import LumiKernel
import os
import SuperLogKit

/// Default `LLMProviderProviding` implementation.
///
/// Acts as a registry of `LumiLLMProvider` instances contributed by
/// LLM Provider plugins. Lookup is O(1) by id; iteration preserves the
/// insertion order so that the provider UI shows a stable list.
@MainActor
public final class LLMProviderManager: LLMProviderManaging, LumiLLMProviderSettingsContributing, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider-manager.service")
    public nonisolated static let emoji = "🧠"
    nonisolated static let verbose = false

    private var llmProviders: [String: any LumiLLMProvider] = [:]
    private var llmProviderOrder: [String] = []
    private var _selectedProviderID: String?
    private var _selectedModel: String?

    /// 共享的 provider 可用性状态。ModelSelector / Settings 页面都引用同一个实例。
    public let providerAvailabilityState = ModelAvailabilityState()

    // MARK: - UserDefaults Keys

    private enum UserDefaultsKeys {
        static let selectedProviderID = "com.coffic.lumi.llmProviderManager.selectedProviderID"
        static let selectedModel = "com.coffic.lumi.llmProviderManager.selectedModel"
    }

    public init() {
        // Restore persisted selection from UserDefaults
        _selectedProviderID = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedProviderID)
        _selectedModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedModel)

        if Self.verbose {
            Self.logger.info("\(Self.t)LLMProviderManager restored: provider=\(self._selectedProviderID ?? "nil"), model=\(self._selectedModel ?? "nil")")
        }
    }

    // MARK: - LLMProviderProviding

    public func allLLMProviders() -> [any LumiLLMProvider] {
        if Self.verbose {
            Self.logger.info("\(Self.t)allLLMProviders ➡️ 当前已注册 \(self.llmProviderOrder.count) 个 provider")
        }
        return llmProviderOrder.compactMap { llmProviders[$0] }
    }

    public func registerLLMProvider(_ provider: any LumiLLMProvider) throws {
        let id = type(of: provider).info.id
        guard !id.isEmpty else {
            throw LumiKernelError.llmProviderRegistrationFailed(
                providerType: String(describing: type(of: provider)),
                reason: "provider 声明的 info.id 为空"
            )
        }
        let isNew = llmProviders[id] == nil
        if isNew {
            llmProviderOrder.append(id)
        }
        llmProviders[id] = provider
        if Self.verbose {
            Self.logger.info("\(Self.t)registerLLMProvider ➡️ id=\(id) (new=\(isNew), total=\(self.llmProviderOrder.count))")
        }
    }

    public func registerLLMProviders(_ providers: [any LumiLLMProvider]) throws {
        for provider in providers {
            let id = type(of: provider).info.id
            guard !id.isEmpty else {
                throw LumiKernelError.llmProviderRegistrationFailed(
                    providerType: String(describing: type(of: provider)),
                    reason: "provider 声明的 info.id 为空"
                )
            }
            let isNew = llmProviders[id] == nil
            if isNew {
                llmProviderOrder.append(id)
            }
            llmProviders[id] = provider
            if Self.verbose {
                Self.logger.info("\(Self.t)registerLLMProviders ➡️ id=\(id) (new=\(isNew))")
            }
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)registerLLMProviders ➡️ 批量完成, 总计 \(self.llmProviderOrder.count) 个 provider")
        }
    }

    public func unregisterLLMProvider(id: String) {
        let existed = llmProviders.removeValue(forKey: id) != nil
        llmProviderOrder.removeAll { $0 == id }
        if Self.verbose {
            Self.logger.info("\(Self.t)unregisterLLMProvider ➡️ id=\(id), existed=\(existed), remaining=\(self.llmProviderOrder.count)")
        }
    }

    public func llmProvider(id: String) -> (any LumiLLMProvider)? {
        let found = llmProviders[id] != nil
        if Self.verbose {
            Self.logger.info("\(Self.t)llmProvider(id:) ➡️ id=\(id), hit=\(found)")
        }
        return llmProviders[id]
    }

    // MARK: - Provider Selection

    public var selectedProviderID: String? { _selectedProviderID }

    public func selectProvider(id: String) {
        guard llmProviders[id] != nil else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)selectProvider ➡️ 未找到 provider id=\(id)")
            }
            return
        }
        _selectedProviderID = id
        UserDefaults.standard.set(id, forKey: UserDefaultsKeys.selectedProviderID)
        if Self.verbose {
            Self.logger.info("\(Self.t)selectProvider ➡️ 已选择 id=\(id)")
        }
    }

    // MARK: - Model Selection

    public func models(for providerID: String) -> [String] {
        guard let provider = llmProviders[providerID] else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)models(for:) ➡️ 未找到 provider id=\(providerID)")
            }
            return []
        }
        return type(of: provider).info.availableModels
    }

    public var selectedModel: String? { _selectedModel }

    public func selectModel(providerID: String, model: String) {
        selectProvider(id: providerID)
        _selectedModel = model
        UserDefaults.standard.set(model, forKey: UserDefaultsKeys.selectedModel)
        if Self.verbose {
            Self.logger.info("\(Self.t)selectModel ➡️ 已选择 provider=\(providerID), model=\(model)")
        }
    }

    // MARK: - Send

    public func sendToFirstProvider(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        guard let provider = allLLMProviders().first else {
            if Self.verbose {
                Self.logger.error("\(Self.t)sendToFirstProvider ➡️ 没有可用的 LLM provider, 抛 llmProviderUnavailable")
            }
            throw LumiKernelError.llmProviderUnavailable
        }
        let providerID = type(of: provider).info.id
        if Self.verbose {
            Self.logger.info("\(Self.t)sendToFirstProvider ➡️ 选 provider id=\(providerID), model=\(request.model), messages=\(request.messages.count), tools=\(request.tools.count)")
        }
        return try await provider.send(request)
    }

    public func sendToSelectedProvider(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        guard let providerID = _selectedProviderID,
              let provider = llmProviders[providerID] else {
            if Self.verbose {
                Self.logger.error("\(Self.t)sendToSelectedProvider ➡️ 没有选中的 provider, 抛 invalidProviderOrModel")
            }
            throw LumiKernelError.invalidProviderOrModel
        }
        let model = _selectedModel ?? type(of: provider).info.defaultModel
        if Self.verbose {
            Self.logger.info("\(Self.t)sendToSelectedProvider ➡️ 选 provider id=\(providerID), model=\(model), messages=\(request.messages.count), tools=\(request.tools.count)")
        }
        let selectedRequest = LumiLLMRequest(
            messages: request.messages,
            model: model,
            tools: request.tools,
            imageAttachments: request.imageAttachments,
            fileAttachments: request.fileAttachments
        )
        return try await provider.send(selectedRequest)
    }

    // MARK: - LumiLLMProviderSettingsContributing

    /// 由 LLM Provider 插件贡献的 provider 详情视图项。
    ///
    /// 默认返回空 — Manager 自身不贡献视图。LLM Provider 插件可通过
    /// `registerProviderSettingsView(_:)` 在 `onBoot` 之后注册自己的项。
    private var providerSettingsViewItems: [LumiLLMProviderSettingsViewItem] = []

    public func llmProviderSettingsViews(
        lumiCore: (any LumiCoreProviding)?
    ) -> [LumiLLMProviderSettingsViewItem] {
        providerSettingsViewItems
    }

    public func registerProviderSettingsView(_ item: LumiLLMProviderSettingsViewItem) {
        providerSettingsViewItems.removeAll { $0.providerID == item.providerID }
        providerSettingsViewItems.append(item)
    }
}
