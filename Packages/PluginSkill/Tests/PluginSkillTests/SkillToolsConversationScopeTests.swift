import Testing
import Foundation
import KitAgentTool
import ProviderSkill
@testable import PluginSkill

/// 锁定 #789：list / read / update / delete_skill 的项目路径回退链必须是
/// 「显式 `project_path` → 会话绑定项目 → UI 当前项目」，会话绑定项目优先于
/// UI 当前项目。
///
/// 本文件只覆盖**不写进程级单例 `SkillRuntime`** 的部分（纯函数回退链 + 显式
/// 路径优先 + Context 接线）。「UI 当前项目 = B、会话 = A」这一确定性回归放在
/// `CreateSkillToolTests.projectPathFallback`（唯一的 `.serialized` 单例用例）里，
/// 避免跨套件并行踩踏全局状态。
@Suite("Skill Tools Conversation Scope")
struct SkillToolsConversationScopeTests {

    // MARK: - Helpers

    private func makeProjectDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-scope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func arguments(_ pairs: [String: Any]) -> [String: ToolArgument] {
        pairs.mapValues { ToolArgument($0) }
    }

    private func makeContext(projectPath: String?) -> ToolExecutionContext {
        ToolExecutionContext(
            jobID: UUID().uuidString,
            conversationID: UUID(),
            conversationProjectPathProvider: { projectPath }
        )
    }

    private func seedSkill(project: URL, name: String, content: String) async throws {
        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: name,
            title: name,
            description: "scope 测试",
            content: content
        )
    }

    // MARK: - 纯函数回退链（不依赖 SkillRuntime）

    @Test("resolveProjectPath 会话项目优先于当前项目，显式路径最优先")
    func resolveProjectPathConversationPriority() async {
        // 提供会话项目时，无论当前项目为何值，都不应落到当前项目这一层。
        #expect(await SkillToolSupport.resolveProjectPath(
            arguments([:]), conversationProjectPath: "/conv"
        ) == "/conv")
        // 显式路径优先于会话项目。
        #expect(await SkillToolSupport.resolveProjectPath(
            arguments(["project_path": "/explicit"]), conversationProjectPath: "/conv"
        ) == "/explicit")
        // 空白显式路径等同省略，回退到会话项目（#890 语义延伸到会话层）。
        #expect(await SkillToolSupport.resolveProjectPath(
            arguments(["project_path": "   "]), conversationProjectPath: "/conv"
        ) == "/conv")
    }

    // MARK: - Context 接线（显式路径优先，不写 SkillRuntime）

    @Test("显式 project_path 仍优先于会话绑定项目")
    @MainActor
    func readExplicitPathBeatsConversationProject() async throws {
        let projectA = try makeProjectDir()
        let projectB = try makeProjectDir()
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }
        try await seedSkill(project: projectB, name: "explicit", content: "B 显式")

        // 会话绑定 A，但显式传 B：必须读 B（A 没有该技能，误用 A 会抛 notFound）。
        let read = try await ReadSkillTool().executeResult(
            context: makeContext(projectPath: projectA.path),
            arguments: arguments(["project_path": projectB.path, "name": "explicit"])
        )
        let data = try #require(read.content.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let skill = try #require(json["skill"] as? [String: Any])
        #expect((skill["content"] as? String)?.contains("B 显式") == true)
    }

    @Test("未传路径时四个工具都经 Context 落到会话绑定项目")
    @MainActor
    func toolsRouteThroughConversationProject() async throws {
        let projectA = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: projectA) }
        try await seedSkill(project: projectA, name: "scoped", content: "A 正文")
        await SkillService.shared.invalidateAllCache()
        let context = makeContext(projectPath: projectA.path)

        // list：经 Context 拿到 A，列出 A 的技能。
        let listed = try await ListSkillsTool().executeResult(
            context: context, arguments: arguments(["include_base": false])
        )
        let listData = try #require(listed.content.data(using: .utf8))
        let listJSON = try #require(JSONSerialization.jsonObject(with: listData) as? [String: Any])
        let names = (listJSON["skills"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
        #expect(names?.contains("scoped") == true)

        // read：经 Context 读 A 的正文。
        let read = try await ReadSkillTool().executeResult(
            context: context, arguments: arguments(["name": "scoped"])
        )
        #expect(read.content.contains("A 正文"))

        // update：经 Context 改 A。
        _ = try await UpdateSkillTool().executeResult(
            context: context, arguments: arguments(["name": "scoped", "content": "改后"])
        )
        let body = try String(
            contentsOf: projectA.appendingPathComponent(".lumi/skills/scoped/SKILL.md"),
            encoding: .utf8
        )
        #expect(body.contains("改后"))

        // delete：经 Context 删 A。
        _ = try await DeleteSkillTool().executeResult(
            context: context, arguments: arguments(["name": "scoped"])
        )
        #expect(!FileManager.default.fileExists(
            atPath: projectA.appendingPathComponent(".lumi/skills/scoped").path
        ))
        await SkillService.shared.invalidateAllCache()
    }
}