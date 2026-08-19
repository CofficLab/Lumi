import os
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import SuperLogKit
import SwiftUI

/// 缓存命中率统计插件
///
/// 在 Chat 工具栏显示当前对话的平均缓存命中率。
///
/// 复刻自旧版 `Plugins/ConversationCacheHitRatePlugin`：
/// - 从 `MessageManaging.messages(for:)` 获取消息列表
/// - 从 assistant 消息的 `metadata` 读取缓存用量数据
/// - 计算算术平均命中率和加权命中率
@MainActor
public final class ConversationCacheHitRatePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-cache-hit-rate", category: "ConversationCacheHitRate")

    public let id = "com.coffic.lumi.plugin.conversation-cache-hit-rate"
    public let order = 86

    public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Cache Hit Rate",
            description: "Display average cache hit rate for the current conversation",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve required providers")
            return
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 86,
                placement: .toolbarLeading
            ) {
                CacheHitRateToolbarView(
                    conversations: conversations,
                    messages: messages
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}

// MARK: - Cache Hit Rate Stats

/// 缓存命中统计（纯计算）
struct CacheHitRateStats: Equatable {
    /// 有缓存用量数据的请求数（assistant 消息）
    let sampleCount: Int
    /// 每条请求命中率的算术平均（0...1）
    let averageHitRate: Double
    /// 所有请求缓存读取 tokens 之和
    let totalCachedTokens: Int
    /// 所有请求输入 tokens 之和
    let totalInputTokens: Int

    /// 按 token 加权的整体命中率（0...1）
    var weightedHitRate: Double {
        totalInputTokens > 0 ? Double(totalCachedTokens) / Double(totalInputTokens) : 0
    }

    /// 整数百分比文案
    var percentText: String {
        String(format: "%.0f%%", averageHitRate * 100)
    }

    /// 一位小数百分比文案
    var precisePercentText: String {
        String(format: "%.1f%%", averageHitRate * 100)
    }

    static let empty = CacheHitRateStats(
        sampleCount: 0, averageHitRate: 0,
        totalCachedTokens: 0, totalInputTokens: 0
    )

    /// 从一批消息聚合缓存命中统计
    static func compute(messages: [Message]) -> CacheHitRateStats {
        var sampleCount = 0
        var rateSum = 0.0
        var totalCached = 0
        var totalInput = 0

        for message in messages where message.role == .assistant {
            guard let cached = intMetadata(message, "cachedInputTokens"),
                  let total = intMetadata(message, "cacheTotalInputTokens"),
                  total > 0 else { continue }
            sampleCount += 1
            rateSum += Double(cached) / Double(total)
            totalCached += cached
            totalInput += total
        }

        return CacheHitRateStats(
            sampleCount: sampleCount,
            averageHitRate: sampleCount > 0 ? rateSum / Double(sampleCount) : 0,
            totalCachedTokens: totalCached,
            totalInputTokens: totalInput
        )
    }

    private static func intMetadata(_ message: Message, _ key: String) -> Int? {
        message.metadata[key].flatMap { Int($0) }
    }
}
