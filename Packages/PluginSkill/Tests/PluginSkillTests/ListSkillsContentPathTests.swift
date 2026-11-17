import Foundation
import KitAgentTool
import ProviderSkill
import Testing

@testable import PluginSkill

/// 回归 #790：list_skills 的描述承诺返回每个技能的正文路径，实际序列化却漏了
/// `content_path`，调用方拿不到 SKILL.md 的位置（read/update/create 回执都有）。
@Suite("ListSkillsContentPath（#790）")
struct ListSkillsContentPathTests {

    private func arguments(_ pairs: [String: Any]) -> [String: ToolArgument] {
        pairs.mapValues { ToolArgument($0) }
    }

    private func seedProject() async throws -> URL {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-list-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: "seed-skill",
            title: "Seed Skill",
            description: "描述",
            content: "## 正文\n\n内容。"
        )
        return project
    }

    private func items(_ output: String) throws -> [[String: Any]] {
        let data = try #require(output.data(using: .utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(json["skills"] as? [[String: Any]])
    }

    @Test("list_skills 不取正文时也返回项目技能的 content_path")
    func listReturnsContentPathWithoutContent() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        let output = try await ListSkillsTool().execute(arguments: arguments([
            "project_path": project.path,
            "include_base": false,
        ]))

        let item = try #require(try items(output).first)
        let path = try #require(item["content_path"] as? String)
        #expect((path as NSString).lastPathComponent == "SKILL.md")
        #expect(FileManager.default.fileExists(atPath: path))
        #expect(item["content"] == nil, "include_content 默认 false，不应返回正文")
    }

    @Test("list_skills 取正文时 content_path 与 content 同时返回")
    func listReturnsContentPathWithContent() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        let output = try await ListSkillsTool().execute(arguments: arguments([
            "project_path": project.path,
            "include_base": false,
            "include_content": true,
        ]))

        let item = try #require(try items(output).first)
        let path = try #require(item["content_path"] as? String)
        #expect(FileManager.default.fileExists(atPath: path))
        #expect((item["content"] as? String)?.contains("内容。") == true)
    }

    @Test("list_skills 的 content_path 与 read_skill 回执一致")
    func listContentPathMatchesReadSkillReceipt() async throws {
        let project = try await seedProject()
        defer { try? FileManager.default.removeItem(at: project) }

        let listOutput = try await ListSkillsTool().execute(arguments: arguments([
            "project_path": project.path,
            "include_base": false,
        ]))
        let listed = try #require(try items(listOutput).first)

        let readOutput = try await ReadSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "seed-skill",
        ]))
        let readData = try #require(readOutput.data(using: .utf8))
        let readJSON = try #require(try JSONSerialization.jsonObject(with: readData) as? [String: Any])
        let readSkill = try #require(readJSON["skill"] as? [String: Any])

        // 扫描器枚举得到的是真实路径（/private/var/...），read 回执用传入路径
        // （/var/...）；比较解析后的文件身份，而不是文本前缀。
        let listedPath = try #require(listed["content_path"] as? String)
        let readPath = try #require(readSkill["content_path"] as? String)
        #expect(
            URL(fileURLWithPath: listedPath).resolvingSymlinksInPath().path
                == URL(fileURLWithPath: readPath).resolvingSymlinksInPath().path
        )
        #expect((listedPath as NSString).lastPathComponent == "SKILL.md")
    }
}