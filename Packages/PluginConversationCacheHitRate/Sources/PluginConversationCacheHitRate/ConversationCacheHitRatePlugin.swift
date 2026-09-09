import os
import KernelCore
import KitSuperLog
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import SwiftUI

/// 缓存命中率统计插件。
///
/// 在 Chat 工具栏显示当前对话的平均缓存命中率。
@MainActor
public final class ConversationCacheHitRatePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-cache-hit-rate",
        category: "ConversationCacheHitRate"
    )

    public let id = "com.coffic.lumi.plugin.conversation-cache-hit-rate"
    public let order = 86
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-cache-hit-rate",
        name: "Conversation Cache Hit Rate",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    private let toolbarState = CacheHitRateToolbarState()
    private var observer: CacheHitRateObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve required providers")
            return
        }

        observer?.cancel()
        observer = CacheHitRateObserver(
            conversations: conversations,
            messages: messages,
            onConversationChange: { [weak toolbarState] newID in
                toolbarState?.setSelectedConversationID(newID)
            },
            onMessageChange: { [weak toolbarState] conversationID in
                guard conversationID == toolbarState?.selectedConversationID else { return }
                toolbarState?.markMessagesChanged(conversationID: conversationID)
            }
        )

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: order,
                placement: .toolbarLeading
            ) {
                CacheHitRateToolbarView(
                    messages: messages,
                    state: self.toolbarState
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        observer?.cancel()
        observer = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}

@MainActor
final class CacheHitRateToolbarState {
    enum Event {
        case selectedConversationChanged(UUID?)
        case messagesChanged(conversationID: UUID)
    }

    protocol ObserverHandle: AnyObject {
        func cancel()
    }

    private final class Handle: ObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    private(set) var selectedConversationID: UUID?
    private var observers: [UUID: (Event) -> Void] = [:]

    @discardableResult
    func addObserver(_ callback: @escaping (Event) -> Void) -> any ObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func setSelectedConversationID(_ id: UUID?) {
        guard selectedConversationID != id else { return }
        selectedConversationID = id
        notify(.selectedConversationChanged(id))
    }

    func markMessagesChanged(conversationID: UUID) {
        notify(.messagesChanged(conversationID: conversationID))
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}

// MARK: - Cache Hit Rate Stats

/// 缓存命中统计（纯计算）。
struct CacheHitRateStats: Equatable {
    /// 有缓存用量数据的请求数（assistant 消息）。
    let sampleCount: Int
    /// 每条请求命中率的算术平均（0...1）。
    let averageHitRate: Double
    /// 所有请求缓存读取 tokens 之和。
    let totalCachedTokens: Int
    /// 所有请求输入 tokens 之和。
    let totalInputTokens: Int

    /// 按 token 加权的整体命中率（0...1）。
    var weightedHitRate: Double {
        totalInputTokens > 0 ? Double(totalCachedTokens) / Double(totalInputTokens) : 0
    }

    var percentText: String {
        String(format: "%.0f%%", weightedHitRate * 100)
    }

    var precisePercentText: String {
        String(format: "%.1f%%", weightedHitRate * 100)
    }

    static let empty = CacheHitRateStats(
        sampleCount: 0,
        averageHitRate: 0,
        totalCachedTokens: 0,
        totalInputTokens: 0
    )

    /// 从一批消息聚合缓存命中统计。
    ///
    /// 新消息使用 ProviderMessage 的强类型 token 字段；旧消息仍可从
    /// metadata 读取，避免迁移前已保存的消息完全丢失统计。
    static func compute(messages: [Message]) -> CacheHitRateStats {
        var sampleCount = 0
        var rateSum = 0.0
        var totalCached = 0
        var totalInput = 0

        for message in messages where message.role == .assistant {
            guard let cached = metricValue(
                message.cachedInputTokenCount,
                metadata: message.metadata,
                key: "cachedInputTokens"
            ),
            let total = metricValue(
                message.cacheTotalInputTokenCount ?? message.inputTokenCount,
                metadata: message.metadata,
                key: "cacheTotalInputTokens"
            ),
            cached >= 0,
            total > 0 else {
                continue
            }

            let boundedCached = min(cached, total)
            sampleCount += 1
            rateSum += Double(boundedCached) / Double(total)
            totalCached += boundedCached
            totalInput += total
        }

        return CacheHitRateStats(
            sampleCount: sampleCount,
            averageHitRate: sampleCount > 0 ? rateSum / Double(sampleCount) : 0,
            totalCachedTokens: totalCached,
            totalInputTokens: totalInput
        )
    }

    private static func metricValue(
        _ value: Int?,
        metadata: [String: String],
        key: String
    ) -> Int? {
        value ?? metadata[key].flatMap(Int.init)
    }
}

// MARK: - Cache Hit Rate Availability

/// 缓存率暂不可用时的可解释原因。
enum CacheHitRateUnavailability: Equatable {
    case noConversationSelected
    case waitingForResponse
    case providerDidNotReportUsage

    var localizedExplanation: String {
        switch self {
        case .noConversationSelected:
            return LumiPluginLocalization.string("No conversation selected. Select a conversation to see cache hit rate.", bundle: .module)
        case .waitingForResponse:
            return LumiPluginLocalization.string("Waiting for the first assistant response with cache usage data.", bundle: .module)
        case .providerDidNotReportUsage:
            return LumiPluginLocalization.string("The provider did not report cache token usage for this conversation. The model or endpoint may not support caching, the stable prefix may be too short, or no cache has been created yet.", bundle: .module)
        }
    }
}
