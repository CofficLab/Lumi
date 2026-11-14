import Foundation
import KitAgentTool
import Testing

@testable import PluginSkill

/// 回归 #527：read_skill 把 SKILL.md 的读取/解码失败伪装成空正文。
///
/// `skill.loadContent() ?? ""` 在正文存在但无法读取（如非法 UTF-8）时返回
/// `content: ""` 且 `success: true`，调用方无法区分「空正文」与「读取失败」。
/// 正文文件存在却读不出时必须抛错；合法正文与真正的空文件仍正常返回。
@Suite("ReadSkillUndecodableBody（#527）")
struct ReadSkillUndecodableBodyTests {

    private func makeProjectDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-read-body-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func arguments(_ pairs: [String: Any]) -> [String: ToolArgument] {
        pairs.mapValues { ToolArgument($0) }
    }

    /// 直接落盘一个技能目录：合法 metadata.json + 指定字节的 SKILL.md。
    private func seedSkill(project: URL, name: String, body: Data) throws {
        let directory = project.appendingPathComponent(".lumi/skills/\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let metadata = """
        {"name":"\(name)","title":"\(name)","description":"正文读取回归","triggers":[],"version":"1.0.0"}
        """
        try metadata.write(to: directory.appendingPathComponent("metadata.json"), atomically: true, encoding: .utf8)
        try body.write(to: directory.appendingPathComponent("SKILL.md"))
    }

    private func decodeContent(_ output: String) throws -> String {
        let data = try #require(output.data(using: .utf8))
        let receipt = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(receipt["success"] as? Bool == true)
        let skill = try #require(receipt["skill"] as? [String: Any])
        return try #require(skill["content"] as? String)
    }

    @Test("正文存在但非法 UTF-8 时 read_skill 抛错，不伪装成空正文")
    func readUndecodableBodyThrows() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }
        try seedSkill(project: project, name: "broken-body", body: Data([0xFF]))

        await #expect(throws: SkillCreationError.self) { () -> Void in
            _ = try await ReadSkillTool().execute(arguments: arguments([
                "project_path": project.path,
                "name": "broken-body",
            ]))
        }
    }

    @Test("合法正文原样返回")
    func readValidBodyReturnsContent() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }
        try seedSkill(project: project, name: "valid-body", body: Data("hello body".utf8))

        let output = try await ReadSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "valid-body",
        ]))
        #expect(try decodeContent(output) == "hello body")
    }

    @Test("真正的空 SKILL.md 仍按空正文成功返回")
    func readEmptyBodySucceeds() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }
        try seedSkill(project: project, name: "empty-body", body: Data())

        let output = try await ReadSkillTool().execute(arguments: arguments([
            "project_path": project.path,
            "name": "empty-body",
        ]))
        #expect(try decodeContent(output) == "")
    }
}