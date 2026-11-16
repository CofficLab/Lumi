import Foundation
import ProviderSkill
import Testing
@testable import PluginSkill

/// 回归 #526：update_skill 的元数据与正文必须「要么全成、要么全不变」。
///
/// 旧实现先写 metadata.json 再写 SKILL.md，正文写失败时已改的元数据留在盘上，
/// 形成半成品更新。修复：写入前校验两个目标路径，正文写失败时回滚元数据。
@Suite("Skill 更新原子性")
struct UpdateSkillAtomicityTests {

    // MARK: - Helpers

    private func makeProjectDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-atomicity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func skillDirectory(project: URL, name: String) -> URL {
        project
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    private func readTitle(project: URL, name: String) throws -> String {
        let metadataURL = skillDirectory(project: project, name: name)
            .appendingPathComponent("metadata.json")
        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder().decode(SkillMetadata.self, from: data).title
    }

    private func metadataModificationDate(project: URL, name: String) throws -> Date {
        let metadataURL = skillDirectory(project: project, name: name)
            .appendingPathComponent("metadata.json")
        return try metadataURL.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate ?? .distantPast
    }

    /// 把 SKILL.md 换成同名目录：扫描器只看 fileExists，仍判定技能有效。
    private func occupyBodyWithDirectory(project: URL, name: String) throws {
        let bodyURL = skillDirectory(project: project, name: name)
            .appendingPathComponent("SKILL.md")
        try FileManager.default.removeItem(at: bodyURL)
        try FileManager.default.createDirectory(at: bodyURL, withIntermediateDirectories: true)
    }

    // MARK: - 预校验：正文目标被目录占用时提前拒绝（#526 复现）

    @Test("正文路径被目录占用时，带标题与正文的更新被拒绝且元数据不变")
    func directoryOccupiedBodyRejectsUpdateAndKeepsMetadata() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: "demo",
            title: "Original",
            description: "描述",
            content: "旧正文"
        )
        try occupyBodyWithDirectory(project: project, name: "demo")
        let metadataDateBefore = try metadataModificationDate(project: project, name: "demo")

        await #expect(throws: SkillCreationError.self) {
            try await SkillCreationService.shared.updateSkill(
                projectPath: project.path,
                name: "demo",
                title: "Changed",
                content: "新正文"
            )
        }

        // 关键断言：失败的更新不得留下已改的元数据。
        #expect(try readTitle(project: project, name: "demo") == "Original")
        // 预校验在任何写入前拒绝，metadata.json 根本未被重写（修改时间不变）。
        #expect(try metadataModificationDate(project: project, name: "demo") == metadataDateBefore)
        // 正文目录原样保留，未被写入破坏。
        var isDirectory: ObjCBool = false
        let bodyURL = skillDirectory(project: project, name: "demo")
            .appendingPathComponent("SKILL.md")
        #expect(FileManager.default.fileExists(atPath: bodyURL.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }

    @Test("正文路径被目录占用时，仅改正文的更新也被拒绝且元数据不变")
    func directoryOccupiedBodyRejectsContentOnlyUpdate() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: "demo",
            title: "Original",
            description: "描述",
            content: "旧正文"
        )
        try occupyBodyWithDirectory(project: project, name: "demo")

        await #expect(throws: SkillCreationError.self) {
            try await SkillCreationService.shared.updateSkill(
                projectPath: project.path,
                name: "demo",
                content: "新正文"
            )
        }

        #expect(try readTitle(project: project, name: "demo") == "Original")
    }

    // MARK: - 回滚：正文写入中途失败时恢复已改的元数据

    #if os(macOS)
    /// 给文件加/撤 immutable 标志（uchg）。加了 uchg 的普通文件仍能通过
    /// `ensureWritableTarget`（它是普通文件而非目录），但原子写入的 rename
    /// 会被系统拒绝，从而确定性地触发「元数据已写、正文写失败」的回滚分支。
    private func setImmutable(_ url: URL, _ immutable: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        process.arguments = [immutable ? "uchg" : "nouchg", url.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test("正文写入失败时回滚已修改的元数据，技能保持原样")
    func failedBodyWriteRollsBackMetadata() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: "demo",
            title: "Original",
            description: "描述",
            content: "旧正文"
        )
        let bodyURL = skillDirectory(project: project, name: "demo")
            .appendingPathComponent("SKILL.md")
        try setImmutable(bodyURL, true)
        defer { try? setImmutable(bodyURL, false) }

        // 正文原子写入被系统拒绝（EPERM），抛出的是 Foundation 错误而非
        // SkillCreationError；这里只要求「确实失败」，重点在下面的回滚断言。
        do {
            _ = try await SkillCreationService.shared.updateSkill(
                projectPath: project.path,
                name: "demo",
                title: "Changed",
                content: "新正文"
            )
            Issue.record("expected body write to fail on immutable SKILL.md")
        } catch {
            // 预期失败。
        }

        // 元数据已先被写成 Changed，正文失败后必须回滚到 Original。
        #expect(try readTitle(project: project, name: "demo") == "Original")
    }
    #endif

    // MARK: - 正常路径不受影响

    @Test("正常的标题与正文更新同时落盘")
    func normalUpdateWritesMetadataAndBody() async throws {
        let project = try makeProjectDir()
        defer { try? FileManager.default.removeItem(at: project) }

        _ = try await SkillCreationService.shared.createSkill(
            projectPath: project.path,
            name: "demo",
            title: "Original",
            description: "描述",
            content: "旧正文"
        )

        let updated = try await SkillCreationService.shared.updateSkill(
            projectPath: project.path,
            name: "demo",
            title: "New Title",
            content: "# New Title\n\n新正文"
        )
        #expect(updated.title == "New Title")
        #expect(try readTitle(project: project, name: "demo") == "New Title")

        let bodyURL = skillDirectory(project: project, name: "demo")
            .appendingPathComponent("SKILL.md")
        let body = try String(contentsOf: bodyURL, encoding: .utf8)
        #expect(body.contains("新正文"))
    }
}