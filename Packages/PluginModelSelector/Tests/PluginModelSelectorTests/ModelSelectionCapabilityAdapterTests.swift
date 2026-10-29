import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMManager
import Testing
@testable import PluginModelSelector

/// 模型选择器把模型钉到**当前会话**上的行为。
///
/// ## 缺陷场景（UI 测试实测）
///
/// UI 测试里「先建会话、再切模型」之后，下一条消息仍然用**全局**选中模型
/// （桩的默认模型 `ui-test-text`）而不是刚选的模型 —— 表现为
/// 「明明在模型选择器里选了长文本模型，回复却还是短文本」。
///
/// ## 归因
///
/// `ModelSelectionCapabilityAdapter.select(modelID:)` 的分支是：
///
/// ```swift
/// if let conversationID = selectedConversationID, let conversations {
///     conversations.selectModel(id: modelID.rawValue, for: conversationID)
/// } else {
///     llmManager.select(modelID: modelID, reason: .userSelected)
/// }
/// ```
///
/// 只有当 `selectedConversationID` 非空时才会写进会话；否则只改全局。
/// 而 `selectedConversationID` 来自 `conversations.selectedConversationID`。
///
/// 这组用例把「有选中会话 → 写进会话；没有选中会话 → 写全局」两分支钉死，
/// 并额外覆盖一个此前没被钉住的情形：**会话存在但不在 `conversations`
/// 数组里**（例如刚被整表重载替换掉）时，钉选会被静默丢弃。
@MainActor
@Suite(.serialized)
struct ModelSelectionCapabilityAdapterTests {

    /// 只登记一个模型（`ui-test-long`）的最小供应商。
    ///
    /// `DefaultLLMManager.modelRoute(for:)` 要求模型在注册供应商的
    /// `availableModels` 里，否则返回 nil —— 钉选会被 guard 拦掉。
    private final class SingleModelProvider: SuperLLMProvider, @unchecked Sendable {
        let providerID = "ui-test"
        let providerInfo = LLMProviderInfo(
            id: "ui-test",
            displayName: "UI Test",
            defaultModel: "ui-test-long",
            models: [LLMModelInfo(id: "ui-test-long", displayName: "UI Test Long")],
            isLocal: true
        )

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "")
        }
    }

    /// 隔离的 `UserDefaults` 域，供 `DefaultLLMManager` 读写选中态。
    ///
    /// `DefaultLLMManager` 把选中模型持久化到 `LLMManagerUserDefaults.current`，
    /// 默认是 `UserDefaults.standard` —— 测试里必须换成隔离域，
    /// 否则会污染开发者本机的真实偏好（且读到上一次的残留值）。
    private static func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "com.coffic.lumi.test.modelselector.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return (UserDefaults(suiteName: suiteName) ?? .standard, suiteName)
        }
        return (defaults, suiteName)
    }

    /// 有选中会话时，模型必须钉到**该会话**上，而不是只改全局。
    @Test("有选中会话：模型必须钉到会话上")
    func pinsModelToSelectedConversation() throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "pin",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        #expect(conversations.selectedConversationID == conversationID)

        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let previous = LLMManagerUserDefaults.current
        LLMManagerUserDefaults.current = defaults
        defer { LLMManagerUserDefaults.current = previous }

        let llm = DefaultLLMManager()
        try llm.register(SingleModelProvider())
        let adapter = ModelSelectionCapabilityAdapter(conversations: conversations, llmManager: llm)

        let modelID = try #require(LLMModelID(providerID: "ui-test", modelID: "ui-test-long"))
        adapter.select(modelID: modelID.rawValue)

        #expect(
            conversations.modelID(for: conversationID) == modelID.rawValue,
            "模型未钉到会话上（实际 \(conversations.modelID(for: conversationID) ?? "nil")）"
        )
    }

    /// 没有选中会话时，模型只能落到全局 —— 这是既有约定，
    /// 但必须与「有会话」分支明确区分，避免两边都写或都不写。
    @Test("无选中会话：模型落到全局选中态")
    func fallsBackToGlobalSelectionWithoutConversation() throws {
        let conversations = DefaultConversationManager()
        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let previous = LLMManagerUserDefaults.current
        LLMManagerUserDefaults.current = defaults
        defer { LLMManagerUserDefaults.current = previous }

        let llm = DefaultLLMManager()
        try llm.register(SingleModelProvider())
        let adapter = ModelSelectionCapabilityAdapter(conversations: conversations, llmManager: llm)

        let modelID = try #require(LLMModelID(providerID: "ui-test", modelID: "ui-test-long"))
        adapter.select(modelID: modelID.rawValue)

        #expect(
            llm.selectedModelID == modelID,
            "无选中会话时应改全局选中态，实际 \(llm.selectedModelID?.rawValue ?? "nil")"
        )
    }

    /// 会话存在但**不在 `conversations` 数组里**时，钉选不得被静默丢弃。
    ///
    /// `selectModel` 的 guard 要求能在数组里找到会话；找不到就直接
    /// `return` —— 既不写会话也不写全局，用户的模型选择**凭空消失**
    ///（既没生效也没报错）。
    @Test("会话不在缓存数组里：钉选必须仍然生效，不能凭空消失")
    func selectionIsNotSilentlyDroppedWhenConversationMissingFromCache() throws {
        let conversations = DefaultConversationManager()
        let staleID = try conversations.createConversation(
            title: "stale",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        #expect(conversations.selectedConversationID == staleID)

        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let previous = LLMManagerUserDefaults.current
        LLMManagerUserDefaults.current = defaults
        defer { LLMManagerUserDefaults.current = previous }

        let llm = DefaultLLMManager()
        try llm.register(SingleModelProvider())
        let adapter = ModelSelectionCapabilityAdapter(conversations: conversations, llmManager: llm)

        let modelID = try #require(LLMModelID(providerID: "ui-test", modelID: "ui-test-long"))
        adapter.select(modelID: modelID.rawValue)

        let pinnedToConversation = conversations.modelID(for: staleID) == modelID.rawValue
        let pinnedGlobally = llm.selectedModelID == modelID
        #expect(
            pinnedToConversation || pinnedGlobally,
            """
            模型钉选**凭空消失**了：既没写进会话 \
            (实际 \(conversations.modelID(for: staleID) ?? "nil"))，也没写全局 \
            (实际 \(llm.selectedModelID?.rawValue ?? "nil"))。\
            用户表现为「在模型选择器里选了模型，下一条消息却还是旧模型」。
            """
        )
    }
}
