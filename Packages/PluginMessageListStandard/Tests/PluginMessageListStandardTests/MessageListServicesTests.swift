import Foundation
import ProviderConversationState
import ProviderMessage
import Testing
@testable import PluginMessageListStandard

// MARK: - activityMessage 投影

@MainActor
private func services(
    conversationState: StubConversationStateCapability?,
    selected: UUID? = UUID()
) -> MessageListServices {
    MessageListServices(
        conversations: StubConversationCapability(selected: selected),
        conversationState: conversationState,
        developerModeState: DeveloperModeStateViewModel(),
        messages: StubMessageListMessageCapability(page: []),
        rendering: nil, streaming: nil, toolManager: nil,
        agentTurn: nil, promptSuggestions: nil, promptSuggestionExecutor: nil,
        project: nil, toolbar: nil, chat: nil
    )
}

@MainActor
private func snapshot(
    conversationID: UUID,
    activity: ConversationActivity?,
    job: ConversationJobActivity = ConversationJobActivity()
) -> StubConversationStateCapability {
    let stub = StubConversationStateCapability()
    stub.snapshot = ConversationStateSnapshot(
        conversationID: conversationID,
        activity: activity,
        jobActivity: job
    )
    return stub
}

@MainActor
@Test("活动消息：sending / thinking / waitingForUser 各映射到对应文案")
func activityMessageCoversSimpleStates() {
    let conversationID = UUID()

    let sending = services(
        conversationState: snapshot(conversationID: conversationID, activity: .sending),
        selected: conversationID
    )
    let sendingRow = sending.activityMessage(for: conversationID)
    #expect(sendingRow?.role == .status)
    #expect(sendingRow?.conversationID == conversationID)
    #expect(sendingRow?.content.contains("发送") == true)

    let thinking = services(
        conversationState: snapshot(conversationID: conversationID, activity: .thinking),
        selected: conversationID
    )
    #expect(thinking.activityMessage(for: conversationID)?.content.contains("思考") == true)

    let waiting = services(
        conversationState: snapshot(conversationID: conversationID, activity: .waitingForUser),
        selected: conversationID
    )
    #expect(waiting.activityMessage(for: conversationID)?.content.contains("等待") == true)
}

@MainActor
@Test("活动消息：executingTool 有运行中任务时带上任务描述")
func activityMessageUsesJobDescription() {
    let conversationID = UUID()
    let stub = snapshot(
        conversationID: conversationID,
        activity: .executingTool,
        job: ConversationJobActivity(
            currentJobCount: 2,
            runningJobCount: 1,
            recentJobDescription: "读取文件"
        )
    )
    let row = services(conversationState: stub, selected: conversationID)
        .activityMessage(for: conversationID)

    // 有运行中任务时拼接描述：「正在读取文件…」，而非通用文案
    #expect(row?.content.contains("读取文件") == true)
    #expect(row?.content.contains("正在") == true)
}

@MainActor
@Test("活动消息：executingTool 无运行中任务时退回通用文案")
func activityMessageFallsBackWithoutRunningJob() {
    let conversationID = UUID()
    // 有描述但没有运行中的任务 → 不应拼接描述
    let noRunning = snapshot(
        conversationID: conversationID,
        activity: .executingTool,
        job: ConversationJobActivity(currentJobCount: 1, runningJobCount: 0, recentJobDescription: "旧任务")
    )
    let rowA = services(conversationState: noRunning, selected: conversationID)
        .activityMessage(for: conversationID)
    #expect(rowA?.content.contains("旧任务") == false)

    // 没有描述 → 同样退回通用文案
    let noDescription = snapshot(
        conversationID: conversationID,
        activity: .executingTool,
        job: ConversationJobActivity(currentJobCount: 1, runningJobCount: 1, recentJobDescription: nil)
    )
    let rowB = services(conversationState: noDescription, selected: conversationID)
        .activityMessage(for: conversationID)
    #expect(rowB?.content.contains("执行") == true)
}

@MainActor
@Test("活动消息：无活动或缺少会话/状态能力时返回 nil")
func activityMessageReturnsNilWhenUnavailable() {
    let conversationID = UUID()

    // 无 activity
    #expect(services(conversationState: snapshot(conversationID: conversationID, activity: nil), selected: conversationID)
        .activityMessage(for: conversationID) == nil)

    // 无 conversationID
    #expect(services(conversationState: snapshot(conversationID: conversationID, activity: .sending), selected: nil)
        .activityMessage(for: nil) == nil)

    // 无 conversationState 能力
    #expect(services(conversationState: nil, selected: conversationID)
        .activityMessage(for: conversationID) == nil)
}

// MARK: - 服务容器透传

@MainActor
@Test("服务容器：选中会话与详细程度经由会话能力透传")
func servicesProxyConversationCapability() {
    let conversationID = UUID()
    let conversations = StubConversationCapability(selected: conversationID)
    conversations.verbosityByConversation[conversationID] = .detailed

    let container = MessageListServices(
        conversations: conversations,
        conversationState: nil,
        developerModeState: DeveloperModeStateViewModel(),
        messages: nil, rendering: nil, streaming: nil, toolManager: nil,
        agentTurn: nil, promptSuggestions: nil, promptSuggestionExecutor: nil,
        project: nil, toolbar: nil, chat: nil
    )

    #expect(container.selectedConversationID == conversationID)
    #expect(container.verbosity(for: conversationID) == .detailed)
    #expect(container.verbosity(for: nil) == .defaultVerbosity)
}

@MainActor
@Test("服务容器：缺少会话能力时详细程度回落到默认值")
func servicesFallsBackWhenConversationCapabilityMissing() {
    let container = MessageListServices(
        conversations: nil,
        conversationState: nil,
        developerModeState: DeveloperModeStateViewModel(),
        messages: nil, rendering: nil, streaming: nil, toolManager: nil,
        agentTurn: nil, promptSuggestions: nil, promptSuggestionExecutor: nil,
        project: nil, toolbar: nil, chat: nil
    )

    #expect(container.selectedConversationID == nil)
    #expect(container.verbosity(for: UUID()) == .defaultVerbosity)
    #expect(container.activeChatContext == nil)
}
