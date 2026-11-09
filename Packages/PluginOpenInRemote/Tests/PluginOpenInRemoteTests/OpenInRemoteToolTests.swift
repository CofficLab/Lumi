import Foundation
import KitAgentTool
import Testing
@testable import PluginOpenInRemote

/// 锁定 Agent 工具的目标路径解析规则与降级行为。
@Suite("OpenInRemoteTool")
@MainActor
struct OpenInRemoteToolTests {
    /// 测试替身：项目能力只提供固定路径，不做观察。
    private final class StubProjectCapability: OpenInRemoteProjectCapability, @unchecked Sendable {
        let currentProjectPath: String?

        init(currentProjectPath: String?) {
            self.currentProjectPath = currentProjectPath
        }

        func addProjectObserver(
            _ callback: @escaping (OpenInRemoteProjectEvent) -> Void
        ) -> any OpenInRemoteProjectObserverHandle {
            OpenInRemoteTestObserverHandle()
        }
    }

    /// 测试替身：固定返回一个 remote 地址。
    private final class StubGitCapability: OpenInRemoteGitCapability, @unchecked Sendable {
        private let rawRemote: String

        init(rawRemote: String) {
            self.rawRemote = rawRemote
        }

        func remoteURL(atPath path: String, remote: String) async -> String? {
            rawRemote
        }
    }

    @Test("显式路径优先于当前项目路径")
    func explicitPathWinsOverCurrentProject() {
        #expect(
            OpenInRemoteTool.resolvedTargetPath(
                explicitPath: "/explicit",
                currentProjectPath: "/current"
            ) == "/explicit"
        )
    }

    @Test("未提供路径时回退到当前项目路径")
    func fallsBackToCurrentProject() {
        #expect(
            OpenInRemoteTool.resolvedTargetPath(
                explicitPath: nil,
                currentProjectPath: "/current"
            ) == "/current"
        )
        #expect(
            OpenInRemoteTool.resolvedTargetPath(
                explicitPath: "",
                currentProjectPath: "/current"
            ) == "/current"
        )
    }

    @Test("既无显式路径也无当前项目时返回 nil")
    func returnsNilWithoutAnyTarget() {
        #expect(
            OpenInRemoteTool.resolvedTargetPath(
                explicitPath: nil,
                currentProjectPath: nil
            ) == nil
        )
    }

    @Test("工具名与风险等级符合低风险只读约定")
    func exposesToolMetadata() {
        let tool = OpenInRemoteTool(
            projectCapability: StubProjectCapability(currentProjectPath: nil),
            resolver: RemoteRepositoryResolver(
                gitCapability: OpenInRemoteGitCapabilityAdapter(provider: nil)
            )
        )

        #expect(tool.name == "open_in_remote")
        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
        #expect(tool.description(for: .english).contains("browser"))
    }

    @Test("没有项目且未提供路径时抛出错误")
    func reportsMissingTarget() async throws {
        let tool = OpenInRemoteTool(
            projectCapability: StubProjectCapability(currentProjectPath: nil),
            resolver: RemoteRepositoryResolver(
                gitCapability: OpenInRemoteGitCapabilityAdapter(provider: nil)
            )
        )

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [:])
        }
    }

    @Test("仓库没有远程地址时抛出错误")
    func reportsMissingRemoteURL() async throws {
        let tool = OpenInRemoteTool(
            projectCapability: StubProjectCapability(currentProjectPath: "/repo"),
            resolver: RemoteRepositoryResolver(
                gitCapability: OpenInRemoteGitCapabilityAdapter(provider: nil)
            )
        )

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [:])
        }
    }

    /// 回归 #1067：`file://` remote 曾被拼成 `https://file/tmp/repo` 并返回打开成功。
    @Test("本地 file:// remote 报告没有可打开的 web 地址")
    func reportsMissingWebURLForFileRemote() async throws {
        let tool = OpenInRemoteTool(
            projectCapability: StubProjectCapability(currentProjectPath: "/repo"),
            resolver: RemoteRepositoryResolver(
                gitCapability: StubGitCapability(rawRemote: "file:///tmp/repo.git")
            )
        )

        do {
            _ = try await tool.execute(arguments: [:])
            Issue.record("expected the tool to throw for a local file remote")
        } catch let ToolExecutionError.executionFailed(_, reason) {
            #expect(reason.contains("No remote repository URL"))
            #expect(!reason.contains("https://file"))
        }
    }

    /// 回归 #1096：打开失败曾返回普通字符串，导致 `isError == false` 与 completed Job。
    @Test("浏览器拒绝打开时抛出工具执行错误")
    func reportsBrowserOpenFailure() async throws {
        let tool = OpenInRemoteTool(
            projectCapability: StubProjectCapability(currentProjectPath: "/repo"),
            resolver: RemoteRepositoryResolver(
                gitCapability: StubGitCapability(rawRemote: "git@github.com:acme/repo.git")
            ),
            openURL: { _ in false }
        )

        do {
            _ = try await tool.execute(arguments: [:])
            Issue.record("expected the tool to throw when the browser refuses to open")
        } catch let ToolExecutionError.executionFailed(toolName, reason) {
            #expect(toolName == "open_in_remote")
            #expect(reason.contains("browser"))
        }
    }

    @Test("显式路径参数被透传到解析链路")
    func passesExplicitPathThrough() async throws {
        let tool = OpenInRemoteTool(
            projectCapability: StubProjectCapability(currentProjectPath: "/current"),
            resolver: RemoteRepositoryResolver(
                gitCapability: OpenInRemoteGitCapabilityAdapter(provider: nil)
            )
        )

        do {
            _ = try await tool.execute(arguments: ["path": ToolArgument("/explicit")])
            Issue.record("expected the tool to throw for a project without a remote")
        } catch let ToolExecutionError.executionFailed(_, reason) {
            #expect(reason.contains("/explicit"))
            #expect(!reason.contains("/current"))
        }
    }

    @Test("会话绑定项目优先于当前项目")
    func conversationProjectWinsOverCurrentProject() {
        #expect(
            OpenInRemoteTool.resolvedTargetPath(
                explicitPath: nil,
                conversationProjectPath: "/conversation",
                currentProjectPath: "/current"
            ) == "/conversation"
        )
        #expect(
            OpenInRemoteTool.resolvedTargetPath(
                explicitPath: "/explicit",
                conversationProjectPath: "/conversation",
                currentProjectPath: "/current"
            ) == "/explicit"
        )
    }

    @Test("未传 path 时使用会话绑定项目")
    func usesConversationProject() async throws {
        let tool = OpenInRemoteTool(
            projectCapability: StubProjectCapability(currentProjectPath: "/current"),
            resolver: RemoteRepositoryResolver(
                gitCapability: OpenInRemoteGitCapabilityAdapter(provider: nil)
            )
        )
        let context = KitAgentTool.ToolExecutionContext(
            jobID: UUID().uuidString,
            conversationID: UUID(),
            conversationProjectPathProvider: { "/conversation" }
        )

        do {
            _ = try await tool.executeResult(context: context, arguments: [:])
            Issue.record("expected the tool to throw for a project without a remote")
        } catch let ToolExecutionError.executionFailed(_, reason) {
            #expect(reason.contains("/conversation"))
            #expect(!reason.contains("/current"))
        }
    }
}

/// 测试用的空观察句柄。
@MainActor
private final class OpenInRemoteTestObserverHandle: OpenInRemoteProjectObserverHandle {
    func cancel() {}
}
