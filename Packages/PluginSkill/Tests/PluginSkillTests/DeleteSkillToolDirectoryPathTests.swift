import Foundation
import KitAgentTool
import Testing

@testable import PluginSkill

/// 回归 #643：delete_skill 的成功回执必须报告**本次实际删除**的目录。
///
/// 旧实现删除的是 `SkillCreationService` 定位到的真实目录（可能是历史目录
/// `.agent/skills/<name>`），回执却硬编码 `.lumi/skills/<name>` 写入路径，
/// 导致删除历史目录技能后返回一个从未存在过的路径。
@Suite("DeleteSkillToolDirectoryPath")
struct DeleteSkillToolDirectoryPathTests {

    private func makeProjectDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-delete-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func arguments(_ pairs: [String: Any]) -> [String: ToolArgument] {
        pairs.mapValues { ToolArgument($0) }
    }

    /// 在历史目录 `.agent/skills/<name>/` 下放置一个完整技能。
    private func seedLegacySkill(project: URL, name: String) throws -> URL {
        let directory = project.appendingPathComponent(".agent/skills/\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let metadata = """
        {"name":"\(name)","title":"Legacy \(name)","description":"历史目录中的技能","triggers":[],"version":"1.0.0"}
        """
        try metadata.write(to: directory.appendingPathComponent("metadata.json"), atomically: true, encoding: .utf8)
        try "# Legacy \(name)\n\n历史内容。".write(
            to: directory.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        return directory
    }

    private func decodeReceipt(_ output: String) throws -> [String: Any] {
        let data = try #require(output.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("删除历史目录技能时，回执 directory_path 必须是实际删除的 .agent 路径")
    func legacyDeleteReceiptReportsDeletedDirectory() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let legacyDirectory = try seedLegacySkill(project: project, name: "legacy-skill")

        let output = try await DeleteSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "legacy-skill",
        ]))
        let receipt = try decodeReceipt(output)

        #expect(receipt["success"] as? Bool == true)
        #expect(receipt["directory_path"] as? String == legacyDirectory.path)
        // 实际删除的就是历史目录本身。
        #expect(!FileManager.default.fileExists(atPath: legacyDirectory.path))
        // 项目里从未有过 .lumi 条目，回执不得指向它。
        #expect(!FileManager.default.fileExists(
            atPath: project.appendingPathComponent(".lumi/skills/legacy-skill").path
        ))
    }

    @Test("删除 .lumi 技能时，回执 directory_path 保持 .lumi 路径")
    func lumiDeleteReceiptReportsLumiDirectory() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: "current-skill",
            title: "Current Skill",
            description: "当前目录中的技能"
        )
        let lumiDirectory = project.appendingPathComponent(".lumi/skills/current-skill", isDirectory: true)

        let output = try await DeleteSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "current-skill",
        ]))
        let receipt = try decodeReceipt(output)

        #expect(receipt["success"] as? Bool == true)
        #expect(receipt["directory_path"] as? String == lumiDirectory.path)
        #expect(!FileManager.default.fileExists(atPath: lumiDirectory.path))
    }
}