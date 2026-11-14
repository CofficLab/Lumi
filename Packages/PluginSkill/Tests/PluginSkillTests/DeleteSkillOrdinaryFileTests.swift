import Foundation
import KitAgentTool
import Testing

@testable import PluginSkill

/// 回归 #525：delete_skill 只凭 `fileExists` 定位目标，普通文件也会被当作技能删除。
///
/// 技能条目必须是**目录**：残缺目录（缺 metadata.json / SKILL.md）仍允许删除，
/// 但同名普通文件不是技能，必须拒绝并原样保留。
@Suite("DeleteSkillOrdinaryFile（#525）")
struct DeleteSkillOrdinaryFileTests {

    private func makeProjectDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-delete-file-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func arguments(_ pairs: [String: Any]) -> [String: ToolArgument] {
        pairs.mapValues { ToolArgument($0) }
    }

    @Test("delete_skill 拒绝删除同名普通文件，文件原样保留")
    func deleteOrdinaryFileIsRejected() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let skillsDir = project.appendingPathComponent(".lumi/skills", isDirectory: true)
        try FileManager.default.createDirectory(at: skillsDir, withIntermediateDirectories: true)
        let ordinaryFile = skillsDir.appendingPathComponent("not-a-skill")
        try "important content".write(to: ordinaryFile, atomically: true, encoding: .utf8)

        await #expect(throws: SkillCreationError.self) { () -> Void in
            _ = try await DeleteSkillTool().execute(arguments: arguments([
                "project_path": project.path,
                "name": "not-a-skill",
            ]))
        }

        #expect(FileManager.default.fileExists(atPath: ordinaryFile.path), "普通文件不得被删除")
        let content = try String(contentsOf: ordinaryFile, encoding: .utf8)
        #expect(content == "important content", "文件内容必须原样保留")
    }

    @Test("delete_skill 仍可删除残缺的技能目录（无 metadata.json / SKILL.md）")
    func deleteIncompleteDirectoryStillSucceeds() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let brokenDir = project.appendingPathComponent(".lumi/skills/broken-skill", isDirectory: true)
        try FileManager.default.createDirectory(at: brokenDir, withIntermediateDirectories: true)
        try "stray".write(to: brokenDir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let output = try await DeleteSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "broken-skill",
        ]))

        #expect(output.contains("\"success\" : true"), "残缺目录仍应能被删除")
        #expect(!FileManager.default.fileExists(atPath: brokenDir.path), "残缺目录应被移除")
    }
}