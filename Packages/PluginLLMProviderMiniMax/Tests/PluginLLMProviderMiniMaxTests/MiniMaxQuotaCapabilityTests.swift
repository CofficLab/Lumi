import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMiniMax

/// 「生效供应商」的判定：对话钉选优先、否则回落到全局选中。
///
/// ## 要解决的缺陷
///
/// 配额 chip 的门控原本只看**全局选中**供应商。但模型可以钉在**单个对话**上
/// （`ConversationManaging.modelID(for:)`），请求实际发给谁由
/// 「对话钉选优先、否则回落全局选中」决定（与
/// `AgentLoopManager.resolveModelRoute(for:)` 同口径）。
///
/// 于是多供应商并存的场景下会出现两种错误展示：
///
/// - 切到用 MiniMax 的对话，工具栏**不显示** MiniMax 剩余额度（用户报的现象）；
/// - 切到用其它供应商的对话，反而显示 MiniMax 剩余额度。
@MainActor
@Suite("MiniMax 生效供应商判定")
struct MiniMaxQuotaCapabilityTests {

    // MARK: - 供应商桩

    /// 只声明一个模型的最小供应商。
    private final class SingleModelProvider: SuperLLMProvider, @unchecked Sendable {
        let providerID: String
        let providerInfo: LLMProviderInfo

        init(id: String, model: String) {
            self.providerID = id
            self.providerInfo = LLMProviderInfo(
                id: id,
                displayName: id,
                defaultModel: model,
                models: [LLMModelInfo(id: model)],
                isLocal: true
            )
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "")
        }
    }

    /// 隔离的偏好域，避免读写开发者本机的真实选中态。
    private static func withIsolatedDefaults<T>(_ body: () throws -> T) rethrows -> T {
        let suiteName = "com.coffic.lumi.test.minimaxquota.\(UUID().uuidString)"
        let previous = LLMManagerUserDefaults.current
        defer { LLMManagerUserDefaults.current = previous }
        LLMManagerUserDefaults.current = UserDefaults(suiteName: suiteName) ?? .standard
        return try body()
    }

    /// 注册 MiniMax + 另一个供应商，并把全局选中断到 `globalProvider`。
    @MainActor
    private static func makeManager(
        globalProvider: String
    ) throws -> DefaultLLMManager {
        let manager = DefaultLLMManager()
        try manager.register(SingleModelProvider(id: "minimax-tokenplan", model: "MiniMax-M3"))
        try manager.register(SingleModelProvider(id: "openai", model: "gpt-4o"))
        manager.select(providerID: globalProvider, model: nil, reason: .userSelected)
        return manager
    }

    // MARK: - 判定

    @Test("对话钉选 MiniMax 时生效供应商是 MiniMax，即使全局选的是别的供应商")
    func conversationPinnedToMiniMaxWinsOverGlobalSelection() throws {
        try Self.withIsolatedDefaults {
            let manager = try Self.makeManager(globalProvider: "openai")
            let conversations = DefaultConversationManager()
            let conversationID = try conversations.createConversation(
                title: "minimax chat",
                projectPath: nil,
                providerID: "minimax-tokenplan",
                modelName: "MiniMax-M3"
            )
            conversations.selectConversation(id: conversationID)

            let capability = MiniMaxQuotaCapabilityAdapter(
                llmManager: manager,
                conversations: conversations
            )
            defer { capability.cancel() }

            #expect(capability.effectiveProviderID == "minimax-tokenplan")
            #expect(manager.selectedProviderID == "openai", "全局选中应保持不变")
        }
    }

    @Test("对话钉选其它供应商时不显示 MiniMax 配额")
    func conversationPinnedToOtherProviderHidesMiniMaxQuota() throws {
        try Self.withIsolatedDefaults {
            let manager = try Self.makeManager(globalProvider: "minimax-tokenplan")
            let conversations = DefaultConversationManager()
            let conversationID = try conversations.createConversation(
                title: "openai chat",
                projectPath: nil,
                providerID: "openai",
                modelName: "gpt-4o"
            )
            conversations.selectConversation(id: conversationID)

            let capability = MiniMaxQuotaCapabilityAdapter(
                llmManager: manager,
                conversations: conversations
            )
            defer { capability.cancel() }

            #expect(capability.effectiveProviderID == "openai")
        }
    }

    @Test("对话未钉选模型时回落到全局选中")
    func unpinnedConversationFallsBackToGlobalSelection() throws {
        try Self.withIsolatedDefaults {
            let manager = try Self.makeManager(globalProvider: "minimax-tokenplan")
            let conversations = DefaultConversationManager()
            let conversationID = try conversations.createConversation(
                title: "unpinned",
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            conversations.selectConversation(id: conversationID)

            let capability = MiniMaxQuotaCapabilityAdapter(
                llmManager: manager,
                conversations: conversations
            )
            defer { capability.cancel() }

            #expect(capability.effectiveProviderID == "minimax-tokenplan")
        }
    }

    @Test("对话钉选的模型已下架时回落到全局选中")
    func staleConversationPinFallsBackToGlobalSelection() throws {
        try Self.withIsolatedDefaults {
            let manager = try Self.makeManager(globalProvider: "minimax-tokenplan")
            let conversations = DefaultConversationManager()
            // 钉选一个 MiniMax 已不再提供的模型 → 解析不出路由 → 回落全局。
            let conversationID = try conversations.createConversation(
                title: "stale",
                projectPath: nil,
                providerID: "minimax-tokenplan",
                modelName: "MiniMax-Retired-Model"
            )
            conversations.selectConversation(id: conversationID)

            let capability = MiniMaxQuotaCapabilityAdapter(
                llmManager: manager,
                conversations: conversations
            )
            defer { capability.cancel() }

            #expect(capability.effectiveProviderID == "minimax-tokenplan")
        }
    }

    // MARK: - 变化通知

    @Test("切换对话时生效供应商变化会通知观察者")
    func switchingConversationNotifiesObserver() throws {
        try Self.withIsolatedDefaults {
            let manager = try Self.makeManager(globalProvider: "openai")
            let conversations = DefaultConversationManager()

            let miniMaxChat = try conversations.createConversation(
                title: "minimax chat",
                projectPath: nil,
                providerID: "minimax-tokenplan",
                modelName: "MiniMax-M3"
            )
            let openAIChat = try conversations.createConversation(
                title: "openai chat",
                projectPath: nil,
                providerID: "openai",
                modelName: "gpt-4o"
            )

            let capability = MiniMaxQuotaCapabilityAdapter(
                llmManager: manager,
                conversations: conversations
            )
            defer { capability.cancel() }

            var observed: [String?] = []
            let handle = capability.addObserver { providerID in
                observed.append(providerID)
            }
            defer { handle.cancel() }

            conversations.selectConversation(id: miniMaxChat)
            conversations.selectConversation(id: openAIChat)

            #expect(observed == ["minimax-tokenplan", "openai"])
        }
    }

    @Test("生效供应商没变时不重复通知")
    func unchangedProviderDoesNotNotifyAgain() throws {
        try Self.withIsolatedDefaults {
            let manager = try Self.makeManager(globalProvider: "minimax-tokenplan")
            let conversations = DefaultConversationManager()
            let conversationID = try conversations.createConversation(
                title: "unpinned",
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            conversations.selectConversation(id: conversationID)

            let capability = MiniMaxQuotaCapabilityAdapter(
                llmManager: manager,
                conversations: conversations
            )
            defer { capability.cancel() }

            var notifyCount = 0
            let handle = capability.addObserver { _ in notifyCount += 1 }
            defer { handle.cancel() }

            // 再建一个未钉选的会话并切过去：生效供应商仍是 MiniMax。
            let another = try conversations.createConversation(
                title: "another",
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            conversations.selectConversation(id: another)

            #expect(notifyCount == 0)
        }
    }

    @Test("对话钉选模型后生效供应商随之更新")
    func pinningModelUpdatesEffectiveProvider() throws {
        try Self.withIsolatedDefaults {
            let manager = try Self.makeManager(globalProvider: "openai")
            let conversations = DefaultConversationManager()
            let conversationID = try conversations.createConversation(
                title: "chat",
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            conversations.selectConversation(id: conversationID)

            let capability = MiniMaxQuotaCapabilityAdapter(
                llmManager: manager,
                conversations: conversations
            )
            defer { capability.cancel() }

            var observed: [String?] = []
            let handle = capability.addObserver { providerID in
                observed.append(providerID)
            }
            defer { handle.cancel() }

            #expect(capability.effectiveProviderID == "openai")

            let modelID = LLMModelID(providerID: "minimax-tokenplan", modelID: "MiniMax-M3")
            #expect(modelID != nil)
            conversations.selectModel(id: modelID!.rawValue, for: conversationID)

            #expect(capability.effectiveProviderID == "minimax-tokenplan")
            #expect(observed == ["minimax-tokenplan"])
        }
    }

    @Test("没有会话能力时回落到全局选中")
    func fallsBackToGlobalSelectionWithoutConversations() throws {
        try Self.withIsolatedDefaults {
            let manager = try Self.makeManager(globalProvider: "minimax-tokenplan")

            let capability = MiniMaxQuotaCapabilityAdapter(
                llmManager: manager,
                conversations: nil
            )
            defer { capability.cancel() }

            #expect(capability.effectiveProviderID == "minimax-tokenplan")
        }
    }
}
