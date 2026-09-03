import Foundation
import KitAgentTool
import Testing
@testable import GitPlugin

/// git_log 结构化输出与消息渲染器解析逻辑的测试。
@Suite("GitLog Structured Renderer Tests")
struct GitLogStructuredRendererTests {

    private func sampleCommits() -> [GitCommitLog] {
        [
            GitCommitLog(
                hash: "0123456789abcdef0123456789abcdef01234567",
                author: "Nookery",
                email: "nook@example.com",
                date: "2026-09-02T12:00:00Z",
                message: "feat: add git log renderer"
            ),
            GitCommitLog(
                hash: "abcdef0123456789abcdef0123456789abcdef01",
                author: "Dev",
                email: "dev@example.com",
                date: "2026-09-01T08:30:00Z",
                message: "fix: resolve path resolution"
            ),
        ]
    }

    @Test("structuredPayload 生成可解析的 JSON 代码块")
    func structuredPayloadRoundTrips() throws {
        let commits = sampleCommits()
        let payload = GitLogTool.structuredPayload(commits)

        #expect(payload.hasSuffix("```"))
        #expect(payload.contains("```json"))

        let json = GitLogRowRenderer.extractJSON(from: payload)
        #expect(json != nil)

        let data = try #require(json?.data(using: .utf8))
        let decoded = try JSONDecoder().decode([GitCommitLog].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded[0].hash == commits[0].hash)
        #expect(decoded[1].message == "fix: resolve path resolution")
    }

    @Test("渲染器从完整工具返回内容中提取 JSON 块")
    func rendererExtractsJSONFromFullContent() throws {
        let commits = sampleCommits()
        let fullContent = "## Git 提交历史\n\n### 1. `0123456` - feat\n\n" + GitLogTool.structuredPayload(commits)

        let json = GitLogRowRenderer.extractJSON(from: fullContent)
        let data = try #require(json?.data(using: .utf8))
        let decoded = try JSONDecoder().decode([GitCommitLog].self, from: data)
        #expect(decoded.count == 2)
    }

    @Test("canRender 命中 git_log 且包含 JSON 块")
    func canRenderMatchesGitLogWithPayload() throws {
        let commits = sampleCommits()
        let toolCall = ToolCall(
            id: "call-1",
            name: GitLogTool.toolName,
            arguments: "{}",
            authorizationState: .userApproved,
            result: ToolCallResult(content: "## Git 提交历史\n" + GitLogTool.structuredPayload(commits)),
            displayDescription: "查看提交历史"
        )

        #expect(GitLogRowRenderer().canRender(toolCall: toolCall))
    }

    @Test("canRender 对无 JSON 块或无结果返回 false")
    func canRenderRejectsPlainResults() {
        let plain = ToolCall(
            id: "call-2",
            name: GitLogTool.toolName,
            arguments: "{}",
            authorizationState: .userApproved,
            result: ToolCallResult(content: "## Git 提交历史\n### 1. abc"),
            displayDescription: nil
        )
        #expect(!GitLogRowRenderer().canRender(toolCall: plain))

        let noResult = ToolCall(
            id: "call-3",
            name: GitLogTool.toolName,
            arguments: "{}",
            authorizationState: .pendingAuthorization,
            result: nil,
            displayDescription: nil
        )
        #expect(!GitLogRowRenderer().canRender(toolCall: noResult))

        let otherTool = ToolCall(
            id: "call-4",
            name: "git_status",
            arguments: "{}",
            authorizationState: .userApproved,
            result: ToolCallResult(content: "## Git 仓库状态\n" + GitLogTool.structuredPayload(sampleCommits())),
            displayDescription: nil
        )
        #expect(!GitLogRowRenderer().canRender(toolCall: otherTool))
    }
}