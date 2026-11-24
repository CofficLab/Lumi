import Foundation
import Testing

@testable import PluginMemory

/// 回归 #361：设置页「项目」标签跨项目管理所有项目记忆。
///
/// 正常保存的项目记忆落在 `Memory/projects/<sanitized>/<id>.md`，旧实现
/// `list(scope: .project, projectPath: nil)` 只扫 `projects/` 根目录，
/// 设置页永远显示空列表；删除同理。锁定递归枚举、按精确路径删除、
/// 以及项目归属还原三件事。
@Suite("设置页跨项目记忆列表")
@MainActor
struct ProjectMemorySettingsListingTests {
    private func makeTempStorage() -> (MemoryFileStorage, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-settings-listing-\(UUID().uuidString)")
        return (MemoryFileStorage(rootURL: url), url)
    }

    @Test("未指定项目时列表必须递归枚举各项目子目录（#361）")
    func projectScopeNilPathListsAcrossProjectSubdirectories() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try await storage.save(
            id: "proj-a-note", type: .project, name: "A Note", description: "",
            content: "content A", scope: .project, projectPath: "/tmp/proj-a"
        )
        _ = try await storage.save(
            id: "proj-b-note", type: .reference, name: "B Ref", description: "",
            content: "content B", scope: .project, projectPath: "/tmp/a b/项目B"
        )

        let items = try await storage.list(scope: .project, projectPath: nil)
        #expect(Set(items.map(\.id)) == ["proj-a-note", "proj-b-note"])
    }

    @Test("指定项目路径时列表仍只返回该项目子目录的记忆")
    func projectScopeExplicitPathStaysSingleProject() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try await storage.save(
            id: "proj-a-note", type: .project, name: "A Note", description: "",
            content: "content A", scope: .project, projectPath: "/tmp/proj-a"
        )
        _ = try await storage.save(
            id: "proj-b-note", type: .project, name: "B Note", description: "",
            content: "content B", scope: .project, projectPath: "/tmp/proj-b"
        )

        let items = try await storage.list(scope: .project, projectPath: "/tmp/proj-a")
        #expect(items.map(\.id) == ["proj-a-note"])
    }

    @Test("按列表返回的精确路径可以删除项目子目录里的记忆（#361）")
    func deleteByFilePathRemovesProjectSubdirectoryMemory() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let item = try await storage.save(
            id: "doomed", type: .project, name: "Doomed", description: "",
            content: "content", scope: .project, projectPath: "/tmp/proj-a"
        )
        try await storage.delete(at: item.filePath)

        let remaining = try await storage.list(scope: .project, projectPath: nil)
        #expect(remaining.isEmpty)
    }

    @Test("按路径删除拒绝 Memory 根目录之外的文件")
    func deleteByFilePathRejectsOutsideRoot() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-outside-\(UUID().uuidString).md")
        try "not a memory".write(to: outside, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: outside) }

        await #expect(throws: MemoryError.self) {
            try await storage.delete(at: outside.path)
        }
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    @Test("条目路径能还原所属项目路径，global 条目返回 nil（#361）")
    func projectPathDerivedFromFilePath() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let projectItem = try await storage.save(
            id: "attributed", type: .project, name: "N", description: "",
            content: "c", scope: .project, projectPath: "/tmp/a b/项目B"
        )
        let globalItem = try await storage.save(
            id: "unattributed", type: .user, name: "G", description: "",
            content: "c", scope: .global, projectPath: nil
        )

        #expect(storage.projectPath(forItemAt: projectItem.filePath) == "/tmp/a b/项目B")
        #expect(storage.projectPath(forItemAt: globalItem.filePath) == nil)
    }
}
