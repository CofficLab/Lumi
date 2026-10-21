import Foundation
import KitTestIsolation
import KitTestSupport
import Testing
@testable import PluginAgentRules

// MARK: - 运行时目录

/// `AgentRulesRuntime.settingsDirectory()` 由 `onBoot` 注入插件配置目录。
///
/// 测试进程里没有注入时守卫会直接拒绝（而不是回退到本机真实数据目录），
/// 这里锁定这条契约的正反两面。
@Suite("AgentRules 运行时目录")
@MainActor
struct AgentRulesRuntimeDirectoryTests {

    @Test("注入目录后 settingsDirectory 返回该目录")
    func usesInjectedDirectory() throws {
        let temporary = try TemporaryDirectory.make("agent-rules-runtime-injected")
        defer { temporary.remove() }
        AgentRulesRuntime.configure(settingsDirectory: temporary.url)
        defer { AgentRulesRuntime.reset() }

        #expect(AgentRulesRuntime.settingsDirectory() == temporary.url)
    }

    @Test("重置后清空注入目录，不再回退到真实数据目录")
    func resetClearsInjectedDirectory() throws {
        let temporary = try TemporaryDirectory.make("agent-rules-runtime-reset")
        defer { temporary.remove() }
        AgentRulesRuntime.configure(settingsDirectory: temporary.url)
        AgentRulesRuntime.reset()
        defer { AgentRulesRuntime.reset() }

        #expect(AgentRulesRuntime.injectedSettingsDirectory == nil)

        // 重置之后不得再回退到本机真实数据目录：测试进程里这条路径必须被拒绝。
        switch IsolatedDirectoryGuard.resolve(
            injected: AgentRulesRuntime.injectedSettingsDirectory,
            owner: "AgentRulesRuntime",
            accessor: "settingsDirectory()",
            fallback: { URL(fileURLWithPath: "/tmp/agent-rules-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未注入目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("AgentRulesRuntime"))
            #expect(reason.contains("settingsDirectory()"))
        }
    }
}
