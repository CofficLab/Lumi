import Foundation
import ProviderConversationState
import ProviderMessageStreaming
import Testing
@testable import PluginMessageListBrief

struct AgentActivityProjectionTests {
    private let conversationID = UUID()

    @Test("流式思考阶段映射为思考活动")
    func thinking() {
        let projection = AgentActivityProjection.resolve(
            conversationState: nil,
            streamingStage: .thinking
        )

        #expect(projection?.phase == .thinking)
        #expect(projection?.title == "正在思考…")
    }

    @Test("生成阶段映射为生成活动")
    func generating() {
        let projection = AgentActivityProjection.resolve(
            conversationState: nil,
            streamingStage: .generating
        )

        #expect(projection?.phase == .generating)
        #expect(projection?.title == "正在生成回复…")
    }

    @Test("工具阶段展示具体工具描述")
    func executingTool() {
        let state = ConversationStateSnapshot(
            conversationID: conversationID,
            activity: .executingTool,
            jobActivity: ConversationJobActivity(
                currentJobCount: 1,
                runningJobCount: 1,
                recentJobDescription: "读取 Sources/App.swift"
            )
        )

        let projection = AgentActivityProjection.resolve(
            conversationState: state,
            streamingStage: .idle
        )

        #expect(projection?.phase == .executingTool)
        #expect(projection?.title == "正在执行")
        #expect(projection?.detail == "读取 Sources/App.swift")
    }

    @Test("多个工具任务显示任务数量")
    func multipleTools() {
        let state = ConversationStateSnapshot(
            conversationID: conversationID,
            activity: .executingTool,
            jobActivity: ConversationJobActivity(
                currentJobCount: 3,
                runningJobCount: 2,
                recentJobDescription: "搜索项目文件"
            )
        )

        let projection = AgentActivityProjection.resolve(
            conversationState: state,
            streamingStage: .idle
        )

        #expect(projection?.title == "正在执行 2 个任务")
        #expect(projection?.detail == "最近：搜索项目文件")
    }

    @Test("等待用户阶段不暴露工具输出")
    func waitingForUser() {
        let state = ConversationStateSnapshot(
            conversationID: conversationID,
            activity: .waitingForUser,
            jobActivity: ConversationJobActivity(
                currentJobCount: 1,
                runningJobCount: 1,
                recentJobDescription: "执行删除操作"
            )
        )

        let projection = AgentActivityProjection.resolve(
            conversationState: state,
            streamingStage: .idle
        )

        #expect(projection?.phase == .waitingForUser)
        #expect(projection?.title == "等待你的确认")
        #expect(projection?.detail == "执行删除操作")
    }

    @Test("空闲阶段不显示活动视图")
    func idle() {
        let projection = AgentActivityProjection.resolve(
            conversationState: nil,
            streamingStage: .idle
        )

        #expect(projection == nil)
    }
}
