import Foundation
import KitLLM
import ProviderAgentRules
import ProviderConversation
import ProviderLifecycleHooks
import ProviderProject
import Testing

@testable import PluginAgentRules

/// 跨会话隔离测试：规则注入钩子必须按「请求所属会话」绑定项目，
/// 而不是 UI 全局当前项目（`ProjectProviding.currentProject`）。
///
/// 场景：会话 A 绑定项目 A、回合仍在执行；用户切到项目 B 的会话后，
/// 全局 `currentProject` 被 `ConversationProjectSyncObserver` 改写为 B。
/// 旧实现从 `project.currentProject.path` 取到 B，于是把 B 的规则注入到
/// A 的提示词里（跨项目串台）。与工具侧 #619 同根，只是发生在注入钩子。
@Suite("AgentRuleInjectionConversationScope")
@MainActor
struct AgentRuleInjectionConversationScopeTests {

    private func makeProject(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rule-inject-scope-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".lumi/rules", isDirectory: true),
            withIntermediateDirectories: true
        )
        return root
    }

    private func writeRule(filename: String, title: String, in project: URL) throws {
        try "# \(title)\n\nBody.".write(
            to: project.appendingPathComponent(".lumi/rules/\(filename)"),
            atomically: true,
            encoding: .utf8
        )
    }

    @Test("注入会话绑定项目的规则，而不是全局当前项目")
    func injectsConversationProjectRules() async throws {
        let projectA = try makeProject("a")
        let projectB = try makeProject("b")
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }
        try writeRule(filename: "from-a.md", title: "From A", in: projectA)
        try writeRule(filename: "from-b.md", title: "From B", in: projectB)

        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "Conversation A",
            projectPath: projectA.path,
            providerID: nil,
            modelName: nil
        )

        // 全局当前项目被切到 B，模拟用户选中了另一个项目的会话。
        // 修复后钩子不再读全局当前项目，这里保留 B 作为环境背景以证明其被忽略。
        let globalProject = DefaultProjectProvider()
        try await globalProject.openProject(at: projectB.path)

        let hook = AgentRuleInjectionHook(conversations: conversations, ruleProvider: DefaultAgentRuleProvider())
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "确保构建成功")],
            conversationID: conversationID
        )

        let result = await hook.apply(to: context)
        let injected = try #require(result.messages.first?.content)

        #expect(injected.contains("From A"))
        #expect(!injected.contains("From B"))
    }
}