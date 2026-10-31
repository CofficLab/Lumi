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

    @Test("没有项目且未提供路径时返回失败说明")
    func reportsMissingTarget() async throws {
        let tool = OpenInRemoteTool(
            projectCapability: StubProjectCapability(currentProjectPath: nil),
            resolver: RemoteRepositoryResolver(
                gitCapability: OpenInRemoteGitCapabilityAdapter(provider: nil)
            )
        )

        let output = try await tool.execute(arguments: [:])

        #expect(output.contains("No project is open"))
    }

    @Test("仓库没有远程地址时返回失败说明")
    func reportsMissingRemoteURL() async throws {
        let tool = OpenInRemoteTool(
            projectCapability: StubProjectCapability(currentProjectPath: "/repo"),
            resolver: RemoteRepositoryResolver(
                gitCapability: OpenInRemoteGitCapabilityAdapter(provider: nil)
            )
        )

        let output = try await tool.execute(arguments: [:])

        #expect(output.contains("No remote repository URL was found"))
    }

    @Test("显式路径参数被透传到解析链路")
    func passesExplicitPathThrough() async throws {
        let tool = OpenInRemoteTool(
            projectCapability: StubProjectCapability(currentProjectPath: "/current"),
            resolver: RemoteRepositoryResolver(
                gitCapability: OpenInRemoteGitCapabilityAdapter(provider: nil)
            )
        )

        let output = try await tool.execute(arguments: ["path": ToolArgument("/explicit")])

        #expect(output.contains("/explicit"))
        #expect(!output.contains("/current"))
    }
}

/// 测试用的空观察句柄。
@MainActor
private final class OpenInRemoteTestObserverHandle: OpenInRemoteProjectObserverHandle {
    func cancel() {}
}
