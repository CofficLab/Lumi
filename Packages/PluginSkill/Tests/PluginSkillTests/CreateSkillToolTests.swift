import Testing
import Foundation
import KitAgentTool
import ProviderProject
import ProviderSkill
@testable import PluginSkill

@Suite("CreateSkillTool")
struct CreateSkillToolTests {

    // MARK: - Helpers

    /// 临时项目目录，测试结束自动清理。
    private func makeProjectDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-create-tool-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func arguments(_ pairs: [String: Any]) -> [String: ToolArgument] {
        pairs.mapValues { ToolArgument($0) }
    }

    // MARK: - Tests

    @Test("创建后写入 metadata.json + SKILL.md，并被扫描器识别")
    func createsScannableSkill() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let tool = CreateSkillTool()
        let output = try await tool.execute(arguments: arguments([
            "project_path": project.path,
            "name": "swiftui-standards",
            "title": "SwiftUI Standards",
            "description": "SwiftUI 开发标准规范",
            "triggers": ["swiftui", "swift"],
            "content": "## 何时使用\n\n编写新的 SwiftUI 视图。",
        ]))

        let data = try #require(output.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["success"] as? Bool == true)
        let skill = try #require(json["skill"] as? [String: Any])
        #expect(skill["name"] as? String == "swiftui-standards")

        // 目录结构符合 SkillDirectoryLoader 约定。
        let dir = project.appendingPathComponent(".agent/skills/swiftui-standards")
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("metadata.json").path))
        let skillMD = try String(contentsOf: dir.appendingPathComponent("SKILL.md"), encoding: .utf8)
        #expect(skillMD.hasPrefix("---"))
        #expect(skillMD.contains("# SwiftUI Standards"))
        #expect(skillMD.contains("编写新的 SwiftUI 视图"))

        // 扫描器能立刻读到，标题与触发词正确。
        let scanned = SkillScanner().scanSkills(projectPath: project.path)
        #expect(scanned.count == 1)
        #expect(scanned[0].name == "swiftui-standards")
        #expect(scanned[0].title == "SwiftUI Standards")
        #expect(scanned[0].triggers == ["swiftui", "swift"])
    }

    @Test("技能名自动规范化为 kebab-case，title 缺省回落为 name")
    func normalizesName() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let tool = CreateSkillTool()
        _ = try await tool.execute(arguments: arguments([
            "project_path": project.path,
            "name": "  My Skill  ",
            "description": "示例",
        ]))

        #expect(FileManager.default.fileExists(
            atPath: project.appendingPathComponent(".agent/skills/my-skill").path
        ))
        let scanned = SkillScanner().scanSkills(projectPath: project.path)
        #expect(scanned.map(\.name) == ["my-skill"])
        #expect(scanned[0].title == "my-skill")
    }

    @Test("同名技能已存在时报错，不覆盖原文件")
    func rejectsDuplicateSkill() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let tool = CreateSkillTool()
        let args: [String: Any] = [
            "project_path": project.path,
            "name": "duplicated",
            "description": "第一次",
        ]
        _ = try await tool.execute(arguments: arguments(args))

        await #expect(throws: SkillCreationError.self) {
            try await tool.execute(arguments: arguments(args))
        }
    }

    @Test("缺少 name 或 description 时抛错")
    func rejectsMissingRequiredArguments() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let tool = CreateSkillTool()

        await #expect(throws: SkillCreationError.self) {
            try await tool.execute(arguments: arguments([
                "project_path": project.path,
                "description": "缺少 name",
            ]))
        }

        await #expect(throws: SkillCreationError.self) {
            try await tool.execute(arguments: arguments([
                "project_path": project.path,
                "name": "no-description",
            ]))
        }
    }

    @Test("正文自带 frontmatter 时原样写入，不重复包装")
    func keepsProvidedFrontmatter() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let body = "---\nname: custom\ndescription: 自定义\n---\n\n# 自定义技能\n\n正文。"
        let tool = CreateSkillTool()
        _ = try await tool.execute(arguments: arguments([
            "project_path": project.path,
            "name": "custom-skill",
            "title": "Custom Skill",
            "description": "自定义 frontmatter",
            "content": body,
        ]))

        let skillMD = try String(
            contentsOf: project.appendingPathComponent(".agent/skills/custom-skill/SKILL.md"),
            encoding: .utf8
        )
        #expect(skillMD == body + "\n")
    }

    @Test("创建后使技能缓存失效，新技能立即可见")
    func invalidatesCacheAfterCreation() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        // 先扫描一次填满 TTL 缓存（工具失效的是 SkillService.shared）。
        let service = SkillService.shared
        await service.invalidateAllCache()
        let before = await service.listSkills(projectPath: project.path)
        #expect(before.isEmpty)

        let tool = CreateSkillTool()
        _ = try await tool.execute(arguments: arguments([
            "project_path": project.path,
            "name": "cached-skill",
            "description": "验证缓存失效",
        ]))

        // 工具内部已 invalidate，同一个 service 立即能读到新技能。
        let after = await service.listSkills(projectPath: project.path)
        #expect(after.map(\.name) == ["cached-skill"])
        await service.invalidateAllCache()
    }

    /// `SkillRuntime` 是进程级单例，且 `SkillPlugin.onBoot` 也会写入它，
    /// 因此把「当前项目回退」相关断言合并到一个串行用例中，避免与其它用例竞争。
    @Test("project_path 回退到当前项目；无当前项目时抛错", .serialized)
    @MainActor
    func projectPathFallback() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        // 1. 无当前项目且未显式传路径 → 抛错。
        SkillRuntime.configure(project: nil)
        let tool = CreateSkillTool()
        await #expect(throws: SkillCreationError.self) {
            try await tool.execute(arguments: arguments([
                "name": "orphan-skill",
                "description": "没有项目",
            ]))
        }

        // 2. 配置当前项目后，未显式传路径 → 写入当前项目。
        let provider = DefaultProjectProvider()
        try await provider.openProject(at: project.path)
        SkillRuntime.configure(project: provider)

        _ = try await tool.execute(arguments: arguments([
            "name": "fallback-skill",
            "description": "来自当前项目",
        ]))
        #expect(FileManager.default.fileExists(
            atPath: project.appendingPathComponent(".agent/skills/fallback-skill").path
        ))

        SkillRuntime.reset()
    }

    @Test("风险等级为 medium，展示描述包含技能名")
    func metadata() {
        let tool = CreateSkillTool()
        #expect(tool.permissionRiskLevel(arguments: [:]) == .medium)
        let description = tool.displayDescription(for: arguments(["name": "my-skill"]))
        #expect(description.contains("my-skill"))
    }
}
