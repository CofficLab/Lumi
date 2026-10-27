import Foundation
import ProviderAgentLoop
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

    @Test("回合运行中但 activity 短暂为空时保留状态视图")
    func runningWithoutActivity() {
        let state = ConversationStateSnapshot(
            conversationID: conversationID,
            agentLoopState: .running
        )

        let projection = AgentActivityProjection.resolve(
            conversationState: state,
            streamingStage: .idle
        )

        #expect(projection?.phase == .thinking)
        #expect(projection?.title == "正在处理…")
    }

    @Test("回合暂停但 activity 短暂为空时保留等待状态")
    func suspendedWithoutActivity() {
        let state = ConversationStateSnapshot(
            conversationID: conversationID,
            agentLoopState: .suspended
        )

        let projection = AgentActivityProjection.resolve(
            conversationState: state,
            streamingStage: .idle
        )

        #expect(projection?.phase == .waitingForUser)
        #expect(projection?.title == "等待你的确认")
    }

    @Test("空闲阶段不显示活动视图")
    func idle() {
        let projection = AgentActivityProjection.resolve(
            conversationState: nil,
            streamingStage: .idle
        )

        #expect(projection == nil)
    }

    // MARK: - §6 状态行恒为一行

    @Test("状态行在细节缺失时只显示标题")
    func statusLineWithoutDetail() {
        let projection = AgentActivityProjection(
            phase: .thinking,
            title: "正在思考…",
            detail: nil
        )

        #expect(projection.statusLineText == "正在思考…")
    }

    @Test("状态行在细节为空字符串时也不产生尾部分隔符")
    func statusLineWithEmptyDetail() {
        let projection = AgentActivityProjection(
            phase: .thinking,
            title: "正在思考…",
            detail: ""
        )

        #expect(projection.statusLineText == "正在思考…")
    }

    @Test("状态行把标题与细节合并到同一行")
    func statusLineMergesDetail() {
        let projection = AgentActivityProjection(
            phase: .executingTool,
            title: "正在执行",
            detail: "正在读取 Sources/App.swift"
        )

        #expect(projection.statusLineText == "正在执行 · 正在读取 Sources/App.swift")
    }

    @Test("状态行恒为单行文本，不含换行")
    func statusLineIsSingleLine() {
        let projection = AgentActivityProjection(
            phase: .executingTool,
            title: "正在执行",
            detail: "正在读取 Sources/App.swift"
        )

        #expect(!projection.statusLineText.contains("\n"))
    }

    @Test("每个活动阶段都能产出一行状态文本")
    func everyStageProducesSingleLineStatusText() {
        let stages: [MessageStreamingStage] = [.sending, .thinking, .generating]

        for stage in stages {
            guard let projection = AgentActivityProjection.resolve(
                conversationState: nil,
                streamingStage: stage
            ) else {
                Issue.record("\(stage) 阶段应产出活动投影")
                continue
            }
            #expect(!projection.statusLineText.isEmpty, "\(stage) 阶段应产出非空状态文本")
            #expect(!projection.statusLineText.contains("\n"), "\(stage) 阶段的状态文本不应换行")
        }
    }
}
