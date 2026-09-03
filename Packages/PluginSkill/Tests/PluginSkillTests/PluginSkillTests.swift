import Combine
import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderLifecycleHooks
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
        var openFileURLs: [URL] = []
        var currentFileURL: URL?
        @Published var tick = false
        init(path: String?) {
            currentProject = path.map { ProjectInfo(name: "test", path: $0) }
        }
        func openProject(at path: String) async throws {}
        func closeProject() async {}
        func refreshProjects() async throws {}
        func updateCurrentFile(_ fileURL: URL?) {}
        func updateOpenFiles(_ fileURLs: [URL]) {}
        func closeFile(_ fileURL: URL) {}
        func synchronizeProjects(_ projects: [ProjectInfo]) {}
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

    @Test("SkillMergePolicy 合并内置与项目技能，同名项目优先")
    func mergePolicy() {
        let builtin = [
            SkillMetadata(name: "swiftui-standards", title: "SwiftUI Standards", description: "内置规范"),
            SkillMetadata(name: "planner", title: "Planner", description: "内置规划"),
        ]
        let project = [
            SkillMetadata(name: "swiftui-standards", title: "项目定制 SwiftUI", description: "项目覆盖版本"),
            SkillMetadata(name: "architect", title: "Architect", description: "项目架构"),
        ]
        let merged = SkillMergePolicy.merge(builtin: builtin, project: project)
        // 去重：同名只保留项目版本
        #expect(merged.count == 3)
        let names = Set(merged.map(\.name))
        #expect(names == ["swiftui-standards", "planner", "architect"])
        // 项目覆盖内置
        #expect(merged.first { $0.name == "swiftui-standards" }?.title == "项目定制 SwiftUI")
        // 排序稳定
        #expect(merged.map(\.name) == ["architect", "planner", "swiftui-standards"])
    }

    @Test("SkillService 合并内置与项目技能")
    func serviceMergesBuiltin() async {
        class FakeBuiltin: BuiltinSkillProviding, @unchecked Sendable {
            func builtinSkills() -> [SkillMetadata] {
                [SkillMetadata(name: "swiftui-standards", title: "SwiftUI Standards", description: "内置规范")]
            }
        }
        struct FakeScanner: SkillScanning {
            func scanSkills(projectPath: String) -> [SkillMetadata] {
                [SkillMetadata(name: "architect", title: "Architect", description: "项目架构")]
            }
        }
        let service = SkillService(scanner: FakeScanner(), builtinProvider: FakeBuiltin())
        let skills = await service.listSkills(projectPath: "/tmp/proj")
        #expect(skills.count == 2)
        #expect(skills.contains { $0.name == "swiftui-standards" })
        #expect(skills.contains { $0.name == "architect" })
    }

    @Test("SkillService 空项目路径时仅返回内置技能")
    func serviceEmptyProjectPath() async {
        class FakeBuiltin: BuiltinSkillProviding, @unchecked Sendable {
            func builtinSkills() -> [SkillMetadata] {
                [SkillMetadata(name: "swiftui-standards", title: "SwiftUI Standards", description: "内置规范")]
            }
        }
        struct FakeScanner: SkillScanning {
            func scanSkills(projectPath: String) -> [SkillMetadata] {
                [SkillMetadata(name: "architect", title: "Architect", description: "项目架构")]
            }
        }
        let service = SkillService(scanner: FakeScanner(), builtinProvider: FakeBuiltin())
        let skills = await service.listSkills(projectPath: "")
        #expect(skills.count == 1)
        #expect(skills.first?.name == "swiftui-standards")
    }

    @Test("SkillService 扫描并缓存")
    func serviceScansAndCaches() async {
        struct EmptyBuiltin: BuiltinSkillProviding {
            func builtinSkills() -> [SkillMetadata] { [] }
        }
        let skills = [SkillMetadata(name: "a", title: "A", description: "desc")]
        let service = SkillService(scanner: MockScanner(skills: skills), builtinProvider: EmptyBuiltin())
        let first = await service.listSkills(projectPath: "/tmp/proj")
        #expect(first.count == 1)
        #expect(first.first?.name == "a")
        // 缓存命中（TTL 内不重新扫描）
        let second = await service.listSkills(projectPath: "/tmp/proj")
        #expect(second.count == 1)
        await service.invalidateCache(projectPath: "/tmp/proj")
    }

    @Test("插件 onBoot 注册工具栏且不抛错")
    func pluginLifecycle() throws {
        let kernel = KernelCoreContainer()
        let project = StubProject(path: "/tmp/proj")
        let chat = DefaultChatSectionProviding()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        try kernel.registerProvider((any ProjectProviding).self, project)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any AgentLoopProviding).self, loop)

        let plugin = SkillPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ProjectProviding).self) != nil)
        try plugin.onShutdown(kernel: kernel)
    }
}

/// 测试用 AgentLoop 桩：保留 responder 语义，落库 assistant 消息。
@MainActor
private final class StubAgentLoop: AgentLoopProviding {
    private let messages: any MessageManaging
    init(messages: any MessageManaging) {
        self.messages = messages
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        .completed
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        throw AgentLoopError.invalidResumeRequest
    }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

}
