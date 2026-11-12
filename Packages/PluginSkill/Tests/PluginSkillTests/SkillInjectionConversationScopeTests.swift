import Foundation
import KitLLM
import ProviderConversation
import ProviderLifecycleHooks
import ProviderProject
import ProviderSkill
import Testing

@testable import PluginSkill

/// 跨会话隔离测试：技能注入钩子必须按「请求所属会话」绑定项目，
/// 而不是 UI 全局当前项目（`ProjectProviding.currentProject`）。
///
/// 场景与规则注入一致：会话 A 绑定项目 A、回合进行中；全局当前项目被切到 B。
/// 旧实现从 `project.currentProject.path` 取到 B，把 B 的项目技能注入 A 的提示词。
@Suite("SkillInjectionConversationScope")
@MainActor
struct SkillInjectionConversationScopeTests {

    private func makeProject(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-inject-scope-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".lumi/skills", isDirectory: true),
            withIntermediateDirectories: true
        )
        return root
    }

    private func writeSkill(name: String, title: String, in project: URL) throws {
        let directory = project.appendingPathComponent(".lumi/skills/\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let metadata = """
        {"name":"\(name)","title":"\(title)","description":"desc","triggers":[],"version":"1.0.0"}
        """
        try metadata.write(to: directory.appendingPathComponent("metadata.json"), atomically: true, encoding: .utf8)
        try "# \(title)\n\nBody.".write(to: directory.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }

    @Test("注入会话绑定项目的技能，而不是全局当前项目")
    func injectsConversationProjectSkills() async throws {
        let projectA = try makeProject("a")
        let projectB = try makeProject("b")
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }
        try writeSkill(name: "from-a", title: "From A", in: projectA)
        try writeSkill(name: "from-b", title: "From B", in: projectB)

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

        let hook = SkillInjectionHook(conversations: conversations, skillProvider: nil, skillService: SkillService())
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "确保构建成功")],
            conversationID: conversationID
        )

        let result = await hook.apply(to: context)
        let injected = try #require(result.messages.first?.content)

        #expect(injected.contains("from-a"))
        #expect(!injected.contains("from-b"))
    }
}