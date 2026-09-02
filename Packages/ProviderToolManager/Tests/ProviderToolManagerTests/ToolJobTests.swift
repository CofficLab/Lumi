import Foundation
import KitAgentTool
import Testing
@testable import ProviderToolManager

struct ToolJobStatusTests {
    @Test("终态可以识别")
    func terminalStatuses() {
        #expect(ToolJobStatus.completed.isTerminal)
        #expect(ToolJobStatus.failed.isTerminal)
        #expect(ToolJobStatus.cancelled.isTerminal)
        #expect(ToolJobStatus.timedOut.isTerminal)
        #expect(!ToolJobStatus.queued.isTerminal)
        #expect(!ToolJobStatus.running.isTerminal)
        #expect(!ToolJobStatus.waitingForUser.isTerminal)
    }

    @Test("Job 状态只能按执行生命周期向前转换")
    func validTransitions() {
        #expect(ToolJobStatus.queued.canTransition(to: .running))
        #expect(ToolJobStatus.queued.canTransition(to: .cancelled))
        #expect(ToolJobStatus.running.canTransition(to: .completed))
        #expect(ToolJobStatus.running.canTransition(to: .failed))
        #expect(ToolJobStatus.running.canTransition(to: .timedOut))
        #expect(ToolJobStatus.running.canTransition(to: .cancelled))
        #expect(ToolJobStatus.completed.canTransition(to: .completed))

        #expect(!ToolJobStatus.completed.canTransition(to: .running))
        #expect(!ToolJobStatus.failed.canTransition(to: .queued))
        #expect(!ToolJobStatus.cancelled.canTransition(to: .completed))
    }
}

struct ToolJobTests {
    @Test("ToolJob 可以 Codable 往返并保留工具调用身份")
    func codableRoundTrip() throws {
        let conversationID = UUID()
        let turnID = UUID()
        let toolCall = ToolCall(
            id: "call-1",
            name: "run_command",
            arguments: #"{"command":"swift test"}"#
        )
        let job = ToolJob(
            conversationID: conversationID,
            turnID: turnID,
            toolCall: toolCall,
            status: .running,
            latestOutput: "Building...",
            outputByteCount: 10
        )

        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(ToolJob.self, from: data)

        #expect(decoded == job)
        #expect(decoded.id == toolCall.id)
        #expect(decoded.toolCall.id == toolCall.id)
        #expect(decoded.conversationID == conversationID)
        #expect(decoded.turnID == turnID)
    }

    @Test("Job ID 始终复用 ToolCall ID")
    func jobIDUsesToolCallID() {
        let toolCall = ToolCall(id: "call-1", name: "run_command", arguments: "{}")
        let job = ToolJob(conversationID: UUID(), toolCall: toolCall)

        #expect(job.id == toolCall.id)
    }
}
