import Testing
import Foundation
import KitAgentTool
import ProviderSkill
@testable import PluginSkill

/// 覆盖 list / read / update / delete 四个工具与共享的 `SkillToolSupport`。
@Suite("Skill CRUD Tools")
struct SkillCRUDToolsTests {

    // MARK: - Helpers

    private func makeProjectDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-crud-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func arguments(_ pairs: [String: Any]) -> [String: ToolArgument] {
        pairs.mapValues { ToolArgument($0) }
    }

    /// 在项目下创建一个基准技能，返回项目路径。
    private func seedProject() async throws -> URL {
        let project = try makeProjectDir()
        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: "seed-skill",
            title: "Seed Skill",
            description: "初始描述",
            triggers: ["alpha", "beta"],
            content: "## 初始正文\n\n原始内容。"
        )
        return project
    }

    /// 解析 list_skills 的 JSON 输出；输出为提示文案时返回 `nil`。
    private func decodeSkills(_ output: String) -> (count: Int, names: [String], contents: [String?])? {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["skills"] as? [[String: Any]] else {
            return nil
        }
        return (
            count: items.count,
            names: items.compactMap { $0["name"] as? String },
            contents: items.map { $0["content"] as? String }
        )
    }

    // MARK: - List

    @Test("list_skills 列出项目技能并标记来源")
    func listReturnsProjectSkills() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        let output = try await ListSkillsTool().execute(arguments: arguments([
            "project_path": project.path,
            "include_base": false,
        ]))

        let result = try #require(decodeSkills(output))
        #expect(result.count == 1)
        #expect(result.names == ["seed-skill"])
        // include_content 默认 false，正文不应返回。
        #expect(result.contents == [nil])
    }

    @Test("list_skills 传 include_content 时返回正文")
    func listIncludesContentOnDemand() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        let output = try await ListSkillsTool().execute(arguments: arguments([
            "project_path": project.path,
            "include_base": false,
            "include_content": true,
        ]))

        let result = try #require(decodeSkills(output))
        #expect(result.count == 1)
        #expect(result.contents.first??.contains("原始内容") == true)
    }

    @Test("list_skills 混合内置底座并按名称排序")
    func listMergesBuiltinBase() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        // 内置底座含 swiftui-standards；项目层为空。
        let output = try await ListSkillsTool().execute(arguments: arguments([
            "project_path": project.path,
            "include_base": true,
        ]))

        let result = try #require(decodeSkills(output))
        #expect(result.names.contains("swiftui-standards"))
        #expect(result.names == result.names.sorted())
    }

    @Test("list_skills limit 截断结果")
    func listRespectsLimit() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        let output = try await ListSkillsTool().execute(arguments: arguments([
            "project_path": project.path,
            "include_base": true,
            "limit": 1,
        ]))
        #expect(try #require(decodeSkills(output)).count == 1)
    }

    @Test("list_skills 无项目且无底座时返回提示文案而非 JSON")
    func listEmptyProjectReturnsHint() async throws {
        let output = try await ListSkillsTool().execute(arguments: arguments([
            "project_path": FileManager.default.temporaryDirectory.path,
            "include_base": false,
        ]))
        #expect(output.contains("No skills found"))
        #expect(decodeSkills(output) == nil)
    }

    // MARK: - Read

    @Test("read_skill 返回元数据与正文")
    func readReturnsMetadataAndBody() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        let output = try await ReadSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "seed-skill",
        ]))

        let data = try #require(output.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let skill = try #require(json["skill"] as? [String: Any])
        #expect(skill["name"] as? String == "seed-skill")
        #expect(skill["title"] as? String == "Seed Skill")
        #expect((skill["content"] as? String)?.contains("原始内容") == true)
    }

    @Test("read_skill 技能不存在时抛 notFound")
    func readMissingSkillThrows() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        await #expect(throws: SkillCreationError.self) { () -> Void in
            _ = try await ReadSkillTool().execute(arguments: arguments([
                "project_path": project.path,
                "name": "ghost",
            ]))
        }
    }

    // MARK: - Update

    @Test("update_skill 只改指定字段，其余保持原值")
    func updatePreservesUntouchedFields() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        _ = try await UpdateSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "seed-skill",
            "description": "更新后的描述",
        ]))

        let skill = try await SkillCreationService.shared.readSkill(
            projectPath: project.path,
            name: "seed-skill"
        )
        let resolved = try #require(skill)
        #expect(resolved.description == "更新后的描述")
        // 未传入的字段不变。
        #expect(resolved.title == "Seed Skill")
        #expect(resolved.triggers == ["alpha", "beta"])
        #expect(resolved.loadContent()?.contains("原始内容") == true)
    }

    @Test("update_skill 传空数组清空 triggers，未传则保留")
    func updateTriggersClearSemantics() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        // 空数组 → 清空。
        _ = try await UpdateSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "seed-skill",
            "triggers": [String](),
        ]))
        var skill = try await SkillCreationService.shared.readSkill(
            projectPath: project.path, name: "seed-skill"
        )
        #expect(try #require(skill).triggers.isEmpty)

        // 不传 triggers → 保持（仍为空）。
        _ = try await UpdateSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "seed-skill",
            "title": "新标题",
        ]))
        skill = try await SkillCreationService.shared.readSkill(
            projectPath: project.path, name: "seed-skill"
        )
        #expect(try #require(skill).triggers.isEmpty)
        #expect(try #require(skill).title == "新标题")
    }

    @Test("update_skill 替换正文")
    func updateReplacesBody() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        _ = try await UpdateSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "seed-skill",
            "content": "---\nname: seed-skill\ndescription: 自定义\n---\n\n# 重写\n\n新的正文。",
        ]))

        let body = try String(
            contentsOf: project.appendingPathComponent(".agent/skills/seed-skill/SKILL.md"),
            encoding: .utf8
        )
        #expect(body.contains("新的正文"))
        #expect(body.hasPrefix("---"))
        // metadata 未被正文污染。
        let skill = try await SkillCreationService.shared.readSkill(
            projectPath: project.path, name: "seed-skill"
        )
        #expect(try #require(skill).description == "初始描述")
    }

    @Test("update_skill 未传任何可改字段时抛错")
    func updateRequiresAField() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        await #expect(throws: SkillCreationError.self) {
            _ = try await UpdateSkillTool().execute(arguments: arguments([
                "project_path": project.path,
                "name": "seed-skill",
            ]))
        }
    }

    @Test("update_skill 技能不存在时抛 notFound")
    func updateMissingSkillThrows() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        await #expect(throws: SkillCreationError.self) { () -> Void in
            _ = try await UpdateSkillTool().execute(arguments: arguments([
                "project_path": project.path,
                "name": "ghost",
                "title": "x",
            ]))
        }
    }

    // MARK: - Delete

    @Test("delete_skill 移除技能目录，扫描器不再返回")
    func deleteRemovesSkill() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        let output = try await DeleteSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "seed-skill",
        ]))
        #expect(output.contains("\"success\" : true"))

        #expect(!FileManager.default.fileExists(
            atPath: project.appendingPathComponent(".agent/skills/seed-skill").path
        ))
        #expect(SkillScanner().scanSkills(projectPath: project.path).isEmpty)
    }

    @Test("delete_skill 技能不存在时抛 notFound")
    func deleteMissingSkillThrows() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        await #expect(throws: SkillCreationError.self) { () -> Void in
            _ = try await DeleteSkillTool().execute(arguments: arguments([
                "project_path": project.path,
                "name": "ghost",
            ]))
        }
    }

    // MARK: - 全链路

    @Test("创建 → 列出 → 读取 → 更新 → 删除 全链路")
    func fullCrudLifecycle() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let create = CreateSkillTool()
        let list = ListSkillsTool()
        let read = ReadSkillTool()
        let update = UpdateSkillTool()
        let delete = DeleteSkillTool()

        _ = try await create.execute(arguments: arguments([
            "project_path": project.path,
            "name": "lifecycle",
            "title": "Lifecycle",
            "description": "全链路技能",
            "content": "正文 v1",
        ]))
        let listed = try await list.execute(arguments: arguments([
            "project_path": project.path, "include_base": false,
        ]))
        #expect(try #require(decodeSkills(listed)).names == ["lifecycle"])

        _ = try await read.execute(arguments: arguments([
            "project_path": project.path, "name": "lifecycle",
        ]))
        _ = try await update.execute(arguments: arguments([
            "project_path": project.path, "name": "lifecycle", "content": "正文 v2",
        ]))
        let updated = try String(
            contentsOf: project.appendingPathComponent(".agent/skills/lifecycle/SKILL.md"),
            encoding: .utf8
        )
        #expect(updated.contains("正文 v2"))

        _ = try await delete.execute(arguments: arguments([
            "project_path": project.path, "name": "lifecycle",
        ]))
        let listedAfter = try await list.execute(arguments: arguments([
            "project_path": project.path, "include_base": false,
        ]))
        // 列表为空时工具返回提示文案而非 JSON。
        #expect(decodeSkills(listedAfter) == nil)
        #expect(listedAfter.contains("No skills found"))
    }

    @Test("delete_skill 拒绝规范化后为空的 name，不会删掉整个 skills 目录")
    func deleteRejectsEmptyNormalizedName() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        let toolsDirectory = project.appendingPathComponent(".agent/skills")

        // 名字只由分隔符组成 → sanitize 后为空 → 必须拒绝。
        await #expect(throws: SkillCreationError.self) { () -> Void in
            _ = try await DeleteSkillTool().execute(arguments: arguments([
                "project_path": project.path,
                "name": "///",
            ]))
        }
        // skills 目录与其中的技能都还在。
        #expect(FileManager.default.fileExists(atPath: toolsDirectory.path))
        #expect(SkillScanner().scanSkills(projectPath: project.path).map(\.name) == ["seed-skill"])
    }

    // MARK: - SkillToolSupport

    @Test("SkillToolSupport 参数解析边界")
    func supportParsers() {
        let args = arguments([
            "empty": "   ",
            "text": "  hello  ",
            "ints": 42,
            "mixed": ["  a ", "", "b"],
            "emptyArray": [String](),
        ])
        #expect(SkillToolSupport.string(args, "empty") == nil)
        #expect(SkillToolSupport.string(args, "text") == "hello")
        #expect(SkillToolSupport.string(args, "missing") == nil)
        #expect(SkillToolSupport.int(args, "ints") == 42)
        // 显式空数组 → 空数组（区别于缺失的 nil）。
        #expect(SkillToolSupport.stringArrayAllowingEmpty(args, "emptyArray") == [])
        #expect(SkillToolSupport.stringArrayAllowingEmpty(args, "missing") == nil)
        #expect(SkillToolSupport.stringArrayAllowingEmpty(args, "mixed") == ["a", "b"])
    }

    @Test("SkillToolSupport 无当前项目且未传路径时返回 nil")
    func supportProjectPathNil() async {
        await MainActor.run { SkillRuntime.reset() }
        #expect(await SkillToolSupport.resolveProjectPath(arguments([:])) == nil)
        #expect(await SkillToolSupport.resolveProjectPath(arguments(["project_path": "/tmp"])) == "/tmp")
    }
}
