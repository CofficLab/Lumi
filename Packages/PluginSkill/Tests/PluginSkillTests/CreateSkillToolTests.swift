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

    private func makeContext(projectPath: String?) -> ToolExecutionContext {
        ToolExecutionContext(
            jobID: UUID().uuidString,
            conversationID: UUID(),
            conversationProjectPathProvider: { projectPath }
        )
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
        let dir = project.appendingPathComponent(".lumi/skills/swiftui-standards")
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

    @Test("正文已带一级标题时不再追加 title，只保留一个 H1")
    func keepsExistingH1WithoutDuplicatingTitle() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let tool = CreateSkillTool()
        let output = try await tool.execute(arguments: arguments([
            "project_path": project.path,
            "name": "existing-heading",
            "title": "Generated Title",
            "description": "示例",
            "content": "# Existing Title\n\nBody",
        ]))

        let data = try #require(output.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["success"] as? Bool == true)

        let skillMD = try String(
            contentsOf: project.appendingPathComponent(".lumi/skills/existing-heading/SKILL.md"),
            encoding: .utf8
        )
        #expect(skillMD.contains("# Existing Title"))
        #expect(!skillMD.contains("# Generated Title"))
        let headings = skillMD.split(separator: "\n").filter { $0.hasPrefix("# ") }
        #expect(headings.count == 1)
    }

    @Test("makeSkillMarkdown 边界情况：空白、空正文、无空格 #、多个 H1")
    func makeSkillMarkdownEdgeCases() {
        let metadata = SkillMetadata(name: "edge", title: "Generated Title", description: "d")

        // 前导空白与换行会被裁剪，仍按已有 H1 处理。
        let leadingWhitespace = SkillCreationService.makeSkillMarkdown(
            metadata: metadata,
            content: "\n\n  # Existing Title\n\nBody"
        )
        #expect(!leadingWhitespace.contains("# Generated Title"))
        #expect(leadingWhitespace.contains("# Existing Title"))

        // `#` 后没有空格不是合法 H1，仍补标题。
        let hashWithoutSpace = SkillCreationService.makeSkillMarkdown(
            metadata: metadata,
            content: "#Heading\n\nBody"
        )
        #expect(hashWithoutSpace.contains("# Generated Title"))

        // 空正文只写 frontmatter 与标题。
        let emptyBody = SkillCreationService.makeSkillMarkdown(metadata: metadata, content: "")
        #expect(emptyBody.contains("# Generated Title"))

        // 正文含多个 H1 时原样保留，不再额外添加 title。
        let multipleH1 = SkillCreationService.makeSkillMarkdown(
            metadata: metadata,
            content: "# One\n\n# Two"
        )
        #expect(multipleH1.contains("# One"))
        #expect(multipleH1.contains("# Two"))
        #expect(!multipleH1.contains("# Generated Title"))
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
            atPath: project.appendingPathComponent(".lumi/skills/my-skill").path
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
            contentsOf: project.appendingPathComponent(".lumi/skills/custom-skill/SKILL.md"),
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
    ///
    /// - Important: #890 的空白 `project_path` 断言也必须放在这里。
    ///   另开一个用例去 configure/reset 单例，会与本用例互相踩踏——
    ///   `.serialized` 只保证同组内串行执行，不隔离全局状态的写入。
    @Test("project_path 回退到当前项目；无当前项目时抛错；空白等同省略", .serialized)
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

        // 1b. 无当前项目且显式传空白 → 同样抛错。
        //     空白不等于「静默成功」：没有任何项目可写时必须失败。
        await #expect(throws: SkillCreationError.self) {
            try await tool.execute(arguments: arguments([
                "project_path": "   ",
                "name": "nowhere-skill",
                "description": "没有可用项目",
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
            atPath: project.appendingPathComponent(".lumi/skills/fallback-skill").path
        ))

        // 2b. 配置当前项目后显式传空白 → 必须落到同一个当前项目（#890）。
        //     模型经常把可选参数显式写成空串（`"project_path": "   "`），
        //     原实现会因空串不是 nil 而短路掉回退，谎报「没有选中当前项目」。
        _ = try await tool.execute(arguments: arguments([
            "project_path": "   ",
            "name": "blank-fallback",
            "description": "空白路径应回退到当前项目",
        ]))
        #expect(FileManager.default.fileExists(
            atPath: project.appendingPathComponent(".lumi/skills/blank-fallback").path
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

    // MARK: - #890 空白 project_path

    /// 空白 `project_path` 同样不得阻断「会话绑定项目」这一层回退。
    ///
    /// - Important: 本用例只走 `executeResult` 的会话项目路径，不读写
    ///   进程级单例 `SkillRuntime`，因此可以与其它用例并行。
    @Test("空白 project_path 回退到会话绑定项目")
    @MainActor
    func blankProjectPathFallsBackToConversationProject() async throws {
        let projectA = try makeProjectDir()
        let projectB = try makeProjectDir()
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        _ = try await CreateSkillTool().executeResult(
            context: makeContext(projectPath: projectA.path),
            arguments: arguments([
                "project_path": "  ",
                "name": "blank-scoped",
                "description": "空白路径应回退到会话项目",
            ])
        )

        #expect(FileManager.default.fileExists(
            atPath: projectA.appendingPathComponent(".lumi/skills/blank-scoped").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: projectB.appendingPathComponent(".lumi/skills/blank-scoped").path
        ))
    }

    @Test("未传 project_path 时写入会话绑定项目")
    @MainActor
    func writesIntoConversationProject() async throws {
        let projectA = try makeProjectDir()
        let projectB = try makeProjectDir()
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        _ = try await CreateSkillTool().executeResult(
            context: makeContext(projectPath: projectA.path),
            arguments: arguments(["name": "scoped-skill", "description": "来自会话项目"])
        )

        #expect(FileManager.default.fileExists(
            atPath: projectA.appendingPathComponent(".lumi/skills/scoped-skill").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: projectB.appendingPathComponent(".lumi/skills/scoped-skill").path
        ))
    }

    @Test("显式 project_path 优先于会话绑定项目")
    @MainActor
    func explicitPathBeatsConversationProject() async throws {
        let projectA = try makeProjectDir()
        let projectB = try makeProjectDir()
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        _ = try await CreateSkillTool().executeResult(
            context: makeContext(projectPath: projectA.path),
            arguments: arguments([
                "project_path": projectB.path,
                "name": "explicit-skill",
                "description": "显式项目",
            ])
        )

        #expect(FileManager.default.fileExists(
            atPath: projectB.appendingPathComponent(".lumi/skills/explicit-skill").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: projectA.appendingPathComponent(".lumi/skills/explicit-skill").path
        ))
    }
}
