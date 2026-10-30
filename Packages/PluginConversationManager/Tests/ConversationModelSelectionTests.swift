import Foundation
import KitLLM
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// 会话级「模型钉选」的行为约定。
///
/// ## 为什么这组用例重要
///
/// 模型选择器（`ModelSelectionCapabilityAdapter.select(modelID:)`）在
/// **有选中会话**时把模型钉到该会话上，而不是只改全局选中态。
/// `PluginAgentLoop.AgentLoopManager.resolveModelRoute(for:)` 读的就是
/// 这个会话级钉选：
///
/// ```swift
/// let conversationModelID = conversations.modelID(for: conversationID)
/// if let conversationModelID, let route = llmManager.modelRoute(for: conversationModelID) {
///     return route          // ← 会话级优先
/// }
/// return llmManager.selectedModelID.flatMap(llmManager.modelRoute(for:))  // ← 回落到全局
/// ```
///
/// 因此「会话级钉选是否真的生效」直接决定该会话后续回合用哪个模型。
/// 一旦钉选被静默丢弃，回合就会**回落到全局选中模型**（UI 测试桩的默认
/// 模型是 `ui-test-text`），表现为「明明选了长文本模型，回复却还是短文本」。
///
/// 这组用例把「钉选 → 落库 → 重新装载 → 回合取路由」这条链路钉死。
@MainActor
@Suite(.serialized)
struct ConversationModelSelectionTests {
    /// 构造一个带隔离数据目录的 `ConversationManager`。
    private func makeManager() -> (ConversationManager, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationModelSelectionTests-\(UUID().uuidString)", isDirectory: true)
        let manager = ConversationManager(store: nil, dataDirectory: directory)
        return (manager, directory)
    }

    /// 钉选模型后，会话自身的 `modelID` 必须变成该模型。
    ///
    /// 这是整条链路的第一环：钉选没写进来，后面全是空谈。
    @Test("钉选模型后会话的 modelID 必须被写入")
    func selectModelWritesConversationModelID() throws {
        let (manager, directory) = makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        manager.conversations = [
            ConversationSummary(id: conversationID, title: "pin", createdAt: Date(), lastMessageAt: Date())
        ]

        let modelID = try #require(LLMModelID(providerID: "ui-test", modelID: "ui-test-long"))
        manager.selectModel(id: modelID.rawValue, for: conversationID)

        #expect(
            manager.modelID(for: conversationID) == modelID.rawValue,
            "钉选后 modelID 未写入会话，实际 \(manager.modelID(for: conversationID) ?? "nil")"
        )
        #expect(
            manager.modelName(for: conversationID) == "ui-test-long",
            "modelName 应由 modelID 解析得到，实际 \(manager.modelName(for: conversationID) ?? "nil")"
        )
    }

    /// 钉选**不能**被「会话列表整体重载」静默丢弃。
    ///
    /// ## 缺陷场景
    ///
    /// `ConversationManager.loadConversations()` 会整体替换 `conversations`
    /// 数组（`self.conversations = loaded`）。若替换时用一份**不含
    /// `modelID`** 的快照，用户的模型选择就被静默回退到全局选中态。
    ///
    /// 用户看到的是「我在会话里换了模型，下一条消息又用回旧模型」，
    /// 且没有任何报错 —— 极难归因。
    @Test("会话列表重载后模型钉选不得丢失")
    func modelSelectionSurvivesConversationReload() async throws {
        let (manager, directory) = makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        manager.conversations = [
            ConversationSummary(id: conversationID, title: "pin", createdAt: Date(), lastMessageAt: Date())
        ]

        let modelID = try #require(LLMModelID(providerID: "ui-test", modelID: "ui-test-long"))
        manager.selectModel(id: modelID.rawValue, for: conversationID)

        // 模拟「从 store 重新装载」：整体替换 conversations 数组。
        // 这正是 `loadConversations()` 里的 `self.conversations = loaded`。
        let reloaded = manager.conversations.map { summary in
            ConversationSummary(
                id: summary.id,
                title: summary.title,
                preview: summary.preview,
                createdAt: summary.createdAt,
                updatedAt: summary.updatedAt,
                lastMessageAt: summary.lastMessageAt,
                verbosity: summary.verbosity,
                reasoningEffort: summary.reasoningEffort,
                language: summary.language,
                automationLevel: summary.automationLevel,
                providerID: summary.providerID,
                modelName: summary.modelName,
                projectPath: summary.projectPath,
                parentConversationID: summary.parentConversationID
            )
        }
        manager.conversations = reloaded

        #expect(
            manager.modelID(for: conversationID) == modelID.rawValue,
            """
            会话列表重载后模型钉选丢失了（实际 \(manager.modelID(for: conversationID) ?? "nil")）。\
            回合将回落到全局选中模型，表现为「换了模型但回复还是旧模型」。
            """
        )
    }
}
