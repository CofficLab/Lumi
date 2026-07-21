import Foundation
import LumiCoreLLMProvider
import LumiKernel
import SuperLogKit
import os

/// Default `LLMProviderProviding` implementation.
///
/// Acts as a registry of `LumiLLMProvider` instances contributed by
/// LLM Provider plugins. Lookup is O(1) by id; iteration preserves the
/// insertion order so that the provider UI shows a stable list.
@MainActor
public final class LLMProviderManager: LLMProviderProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider-manager.service")
    public nonisolated static let emoji = "🧠"
    nonisolated static let verbose = true

    private var llmProviders: [String: any LumiLLMProvider] = [:]
    private var llmProviderOrder: [String] = []

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)LLMProviderManager")
        }
    }

    // MARK: - LLMProviderProviding

    public func allLLMProviders() -> [any LumiLLMProvider] {
        if Self.verbose {
            Self.logger.info("\(Self.t)allLLMProviders ➡️ 当前已注册 \(self.llmProviderOrder.count) 个 provider")
        }
        return llmProviderOrder.compactMap { llmProviders[$0] }
    }

    public func registerLLMProvider(_ provider: any LumiLLMProvider) {
        let id = type(of: provider).info.id
        let isNew = llmProviders[id] == nil
        if isNew {
            llmProviderOrder.append(id)
        }
        llmProviders[id] = provider
        if Self.verbose {
            Self.logger.info("\(Self.t)registerLLMProvider ➡️ id=\(id) (new=\(isNew), total=\(self.llmProviderOrder.count))")
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
}
