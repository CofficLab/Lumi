import Combine
import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderAgentLoop
import ProviderMessage
import ProviderProject

@testable import PluginSkill

@Suite("SkillPlugin")
@MainActor
struct SkillPluginTests {
    /// 内存 ProjectProviding stub。
    @MainActor
    private final class StubProject: ProjectProviding {
        var currentProject: ProjectInfo?
        var projects: [ProjectInfo] = []
        @Published var tick = false
        init(path: String?) {
            currentProject = path.map { ProjectInfo(name: "test", path: $0) }
        }
        func openProject(at path: String) async throws {}
        func closeProject() async {}
        func refreshProjects() async throws {}
    }

    /// Mock scanner：返回固定技能列表。
    private struct MockScanner: SkillScanning {
        let skills: [SkillMetadata]
        func scanSkills(projectPath: String) -> [SkillMetadata] { skills }
    }

    @Test("PromptBuilder 构造技能列表 prompt")
    func promptBuilder() {
        let skills = [
            SkillMetadata(name: "swiftui-expert", title: "SwiftUI Expert", description: "SwiftUI 最佳实践", triggers: ["swiftui"]),
            SkillMetadata(name: "debugger", title: "Debugger", description: "系统化调试", version: "2.0.0"),
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)
        #expect(prompt.contains("Available Skills"))
        #expect(prompt.contains("swiftui-expert"))
        #expect(prompt.contains("debugger"))
    }

    @Test("SkillService 扫描并缓存")
    func serviceScansAndCaches() async {
        let skills = [SkillMetadata(name: "a", title: "A", description: "desc")]
        let service = SkillService(scanner: MockScanner(skills: skills))
        let first = await service.listSkills(projectPath: "/tmp/proj")
        #expect(first.count == 1)
        #expect(first.first?.name == "a")
        // 缓存命中（TTL 内不重新扫描）
        let second = await service.listSkills(projectPath: "/tmp/proj")
        #expect(second.count == 1)
        await service.invalidateCache(projectPath: "/tmp/proj")
    }

    @Test("消息准备器注入技能 system 消息")
    func preparerInjectsSkillMessage() async {
        let project = StubProject(path: "/tmp/proj")
        let skills = [SkillMetadata(name: "swiftui", title: "SwiftUI", description: "desc")]
        let service = SkillService(scanner: MockScanner(skills: skills))
        let preparer = SkillMessagePreparer(project: project, service: service)

        let conversationID = UUID()
        let history = [Message(conversationID: conversationID, role: .user, content: "hi")]
        let prepared = await preparer.prepare(history)

        #expect(prepared.count == 2)
        #expect(prepared.first?.role == .system)
        #expect(prepared.first?.content.contains("swiftui") == true)
        #expect(prepared.last?.content == "hi")
    }

    @Test("无技能时不注入")
    func preparerNoSkills() async {
        let project = StubProject(path: "/tmp/proj")
        let service = SkillService(scanner: MockScanner(skills: []))
        let preparer = SkillMessagePreparer(project: project, service: service)

        let conversationID = UUID()
        let history = [Message(conversationID: conversationID, role: .user, content: "hi")]
        let prepared = await preparer.prepare(history)
        #expect(prepared.count == 1)
    }

    @Test("插件 onBoot 注册工具栏且不抛错")
    func pluginLifecycle() throws {
        let kernel = KernelCoreContainer()
        let project = StubProject(path: "/tmp/proj")
        let chat = DefaultChatSectionProviding()
        let messages = DefaultMessageManaging()
        let loop = DefaultAgentLoopProviding(messages: messages)
        try kernel.registerProvider((any ProjectProviding).self, project)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any AgentLoopProviding).self, loop)

        let plugin = SkillPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ProjectProviding).self) != nil)
        try plugin.onShutdown(kernel: kernel)
    }
}
