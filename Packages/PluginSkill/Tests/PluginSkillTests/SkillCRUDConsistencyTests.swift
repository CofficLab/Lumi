import Foundation
import KitAgentTool
import ProviderSkill
import Testing
@testable import PluginSkill

/// CRUD 与扫描器必须对「什么算有效 Skill」保持同一判断。
///
/// 否则会出现两类不一致：
/// - 列表里能看到、读取却说找不到（残缺条目挡住了历史条目）；
/// - 写入返回成功、Skill 却立刻从扫描结果中消失（写出了扫描器读不回来的文件）。
@Suite("Skill CRUD 与扫描器一致性")
struct SkillCRUDConsistencyTests {

    // MARK: - Helpers

    private func makeProjectDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-consistency-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 在历史目录 `.agent/skills/<name>/` 放一个完整有效的技能。
    private func seedLegacySkill(project: URL, name: String) throws {
        let directory = project
            .appendingPathComponent(".agent", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let metadata = SkillMetadata(
            name: name,
            title: "Legacy Skill",
            description: "历史目录中的完整技能",
            triggers: ["legacy"],
            version: "1.0.0"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(
            to: directory.appendingPathComponent("metadata.json"),
            options: .atomic
        )
        try "# Legacy Skill\n\n正文".write(
            to: directory.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    /// 在 `.lumi/skills/<name>/` 放一个残缺目录（没有 metadata.json / SKILL.md）。
    private func seedBrokenCurrentSkill(project: URL, name: String) throws {
        let directory = project
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - 残缺条目不应挡住历史条目（#705）

    @Test("残缺的 .lumi 条目不会让 read_skill 找不到历史技能")
    func readFallsBackToValidLegacySkill() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        try seedLegacySkill(project: project, name: "example")
        try seedBrokenCurrentSkill(project: project, name: "example")

        // 扫描器能看到它（列表里可见）。
        let scanner = SkillScanner()
        #expect(scanner.scanSkills(projectPath: project.path).map(\.name) == ["example"])

        // 读取也应能找到同一个技能。
        let skill = try await SkillCreationService.shared.readSkill(
            projectPath: project.path,
            name: "example"
        )
        #expect(skill?.name == "example")
        #expect(skill?.title == "Legacy Skill")
    }

    @Test("残缺的 .lumi 条目不会让 update_skill 失败")
    func updateFallsBackToValidLegacySkill() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        try seedLegacySkill(project: project, name: "example")
        try seedBrokenCurrentSkill(project: project, name: "example")

        let updated = try await SkillCreationService.shared.updateSkill(
            projectPath: project.path,
            name: "example",
            description: "更新后的描述"
        )
        #expect(updated.description == "更新后的描述")

        // 更新落在历史目录（原位更新，不做隐式迁移）。
        let legacyMetadata = project
            .appendingPathComponent(".agent", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent("example", isDirectory: true)
            .appendingPathComponent("metadata.json")
        let data = try Data(contentsOf: legacyMetadata)
        let decoded = try JSONDecoder().decode(SkillMetadata.self, from: data)
        #expect(decoded.description == "更新后的描述")
    }

    @Test("只有残缺条目时读取返回 nil")
    func readReturnsNilWhenOnlyBrokenSkillExists() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        try seedBrokenCurrentSkill(project: project, name: "example")

        let skill = try await SkillCreationService.shared.readSkill(
            projectPath: project.path,
            name: "example"
        )
        #expect(skill == nil)
    }

    // MARK: - 写入约束必须与扫描器一致（#704）

    @Test("超出扫描器上限的元数据被拒绝写入")
    func oversizedMetadataIsRejected() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        let limit = SkillDirectoryLoader().maxMetadataSize
        // 1 MiB 上限之上的描述，写出后扫描器一定读不回来。
        let oversized = String(repeating: "a", count: limit + 1024)

        await #expect(throws: SkillCreationError.self) {
            try await SkillCreationService.shared.createSkill(
                projectPath: project.path,
                name: "huge",
                title: "Huge",
                description: oversized
            )
        }

        // 拒绝后不应留下半成品目录。
        let directory = project
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent("huge", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("更新到超限元数据被拒绝，不会让技能从列表消失")
    func oversizedUpdateIsRejected() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: "normal",
            title: "Normal",
            description: "正常描述"
        )

        let limit = SkillDirectoryLoader().maxMetadataSize
        let oversized = String(repeating: "a", count: limit + 1024)

        await #expect(throws: SkillCreationError.self) {
            try await SkillCreationService.shared.updateSkill(
                projectPath: project.path,
                name: "normal",
                description: oversized
            )
        }

        // 技能仍然可用。
        let scanner = SkillScanner()
        #expect(scanner.scanSkills(projectPath: project.path).map(\.name) == ["normal"])
    }

    @Test("正常大小的元数据可以正常创建并被扫描到")
    func normalMetadataIsAccepted() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: "normal",
            title: "Normal",
            description: "正常描述",
            triggers: ["x"]
        )

        let scanner = SkillScanner()
        let skills = scanner.scanSkills(projectPath: project.path)
        #expect(skills.map(\.name) == ["normal"])
        #expect(skills.first?.description == "正常描述")
    }
}
