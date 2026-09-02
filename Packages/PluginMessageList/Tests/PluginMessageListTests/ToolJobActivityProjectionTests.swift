import Foundation
import ProviderConversationState
import Testing
@testable import PluginMessageList

@Suite("Tool Job activity message")
struct ToolJobActivityProjectionTests {
    @Test("工具活动状态保留当前 Job 汇总")
    @MainActor
    func keepsJobActivitySummary() {
        let state = ConversationStateSnapshot(
            conversationID: UUID(),
            activity: .executingTool,
            jobActivity: ConversationJobActivity(
                currentJobCount: 3,
                runningJobCount: 1,
                recentJobDescription: "搜索项目文件"
            )
        )
        #expect(state.jobActivity.currentJobCount == 3)
        #expect(state.jobActivity.runningJobCount == 1)
        #expect(state.jobActivity.recentJobDescription == "搜索项目文件")
    }

    @Test("无 Job 汇总时仍保持旧的工具活动状态")
    func emptyJobActivityIsBackwardCompatible() {
        let activity = ConversationJobActivity()
        #expect(activity.hasJobs == false)
        #expect(activity.currentJobCount == 0)
        #expect(activity.runningJobCount == 0)
    }
}
