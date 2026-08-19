import Combine
import Foundation
import KitLLM
import os
import ProviderLLMManager
import SuperLogKit

/// PluginLLMManager 自研的 `LLMManaging` 实现。
///
/// 组合 `DefaultLLMManager` 作为「供应商注册表 + 选中持久化 + 默认路由」引擎，
/// 本类型显式实现 `LLMManaging` 全部协议成员并转发，同时提供插件化的扩展点：
///
/// - `routingOverride`：自定义「请求 → 供应商」解析（如按会话路由）。返回
///   `(provider, model)` 时优先使用，`nil` 时回退引擎默认（选中项 > 首个注册项）。
/// - 转发 `engine.objectWillChange`，让内核订阅方（UI）在选中态变化时照常刷新。
@MainActor
public final class CustomLLMManager: LLMManaging, @preconcurrency SuperLLMProvider, LLMStreamingProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-manager", category: "CustomLLMManager")
    public nonisolated static let emoji = "🧭"
    nonisolated static let verbose = true

    /// 内部引擎：注册表 + 选中持久化 + 默认路由（`DefaultLLMManager`）。
    private let engine: DefaultLLMManager

    /// 路由扩展点：自定义「请求 → 供应商」解析；`nil` 时走引擎默认逻辑。
    public var routingOverride: ((LLMRequest) -> (any SuperLLMProvider, String?)?)?

    private var cancellables: Set<AnyCancellable> = []

    public init() {
        engine = DefaultLLMManager()
        // 引擎的 @Published 选中态变化时，转发到本类型的 objectWillChange，
        // 保证经内核订阅（registerProvider 默认 forwardsObjectWillChange）的 UI 刷新。
        engine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - LLMManaging: Registration

    public var providerCount: Int { engine.providerCount }

    public func allProviders() -> [any SuperLLMProvider] { engine.allProviders() }

    public func provider(id: String) -> (any SuperLLMProvider)? { engine.provider(id: id) }

    public func register(_ provider: any SuperLLMProvider) throws {
        try engine.register(provider)
        if Self.verbose {
            Self.logger.info("\(Self.t)registered provider: \(provider.providerInfo.id, privacy: .public), total=\(self.providerCount)")
        }
    }

    public func unregister(id: String) {
        engine.unregister(id: id)
        if Self.verbose {
            Self.logger.info("\(Self.t)unregistered provider: \(id, privacy: .public), total=\(self.providerCount)")
        }
    }

    // MARK: - LLMManaging: Selection

    public var selectedProviderID: String? { engine.selectedProviderID }
    public var selectedModel: String? { engine.selectedModel }

    public func models(for providerID: String) -> [String] { engine.models(for: providerID) }

    public func select(providerID: String, model: String?) {
        engine.select(providerID: providerID, model: model)
    }

    // MARK: - SuperLLMProvider / LLMStreamingProviding

    public var providerID: String { engine.providerID }
    public var providerInfo: LLMProviderInfo { engine.providerInfo }

    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
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
        return try await engine.complete(request)
    }

    public func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
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
        return try await engine.streamComplete(request, onChunk: onChunk)
    }
}
