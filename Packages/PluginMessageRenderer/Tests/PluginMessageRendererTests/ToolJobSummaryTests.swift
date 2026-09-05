import Foundation
import KitAgentTool
import ProviderToolManager
import Testing
@testable import PluginMessageRenderer

@Suite("ToolJob UI projection")
struct ToolJobSummaryTests {
    private let baseDate = Date(timeIntervalSince1970: 1_000)

    @Test("所有 Job 状态都有稳定的用户文案")
    func mapsAllStatuses() {
        let statuses: [(ToolJobStatus, String)] = [
            (.queued, "排队中"),
            (.running, "执行中"),
            (.waitingForUser, "等待用户"),
            (.cancelling, "停止中"),
            (.completed, "已完成"),
            (.failed, "失败"),
            (.cancelled, "已停止"),
            (.timedOut, "已超时"),
        ]

        for (status, title) in statuses {
            #expect(ToolJobVisualState(status: status).title == title)
        }
    }

    @Test("运行中的 Job 计算经过时间、进度和可停止状态")
    func projectsLiveJob() {
        let job = makeJob(
            status: .running,
            startedAt: baseDate,
            latestProgress: ToolJobProgress(message: "读取文件", completed: 2, total: 5),
            latestOutput: "line 1\nline 2"
        )
        let projection = ToolJobActivityProjection(
            job: job,
            now: baseDate.addingTimeInterval(138)
        )

        #expect(projection.state == .running)
        #expect(projection.duration == 138)
        #expect(projection.progressText == "读取文件 · 2/5")
        #expect(projection.outputTail == "line 1\nline 2")
        #expect(projection.canStop)
    }

    @Test("终态 Job 不再显示停止操作")
    func terminalJobCannotStop() {
        for status in [ToolJobStatus.completed, .failed, .cancelled, .timedOut, .cancelling] {
            #expect(ToolJobActivityProjection(job: makeJob(status: status)).canStop == false)
        }
    }

    @Test("步骤组摘要覆盖进行中、失败和完成")
    func summarizesJobGroup() {
        let running = makeJob(status: .running, startedAt: baseDate)
        let completed = makeJob(
            id: "completed",
            status: .completed,
            startedAt: baseDate,
            completedAt: baseDate.addingTimeInterval(60)
        )
        #expect(
            ToolStepGroupSummary.summaryText(
                for: [running, completed],
                now: baseDate.addingTimeInterval(138)
            ) == "执行中 · 1/2 · 2m 18s"
        )

        let failed = makeJob(id: "failed", status: .failed)
        #expect(ToolStepGroupSummary.summaryText(for: [failed]) == "已停止 · 1个失败")
    }

    private func makeJob(
        id: String = UUID().uuidString,
        status: ToolJobStatus,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        latestProgress: ToolJobProgress? = nil,
        latestOutput: String = ""
    ) -> ToolJob {
        ToolJob(
            conversationID: UUID(),
            turnID: UUID(),
            toolCall: ToolCall(
                id: id,
                name: "read_file",
                arguments: "{}",
                displayDescription: "读取文件"
            ),
            status: status,
            createdAt: baseDate,
            startedAt: startedAt,
            completedAt: completedAt,
            latestOutput: latestOutput,
            latestProgress: latestProgress
        )
    }
}
