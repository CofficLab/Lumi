import Foundation
import Testing

@testable import PluginMemory

/// 回归 #198：`save_memory` 的 id 若含 `../` 等路径段，旧实现会拼出逃出
/// Memory 根目录的文件路径，从而在任意可写位置写入/覆盖 `.md`。
/// `fileName(forID:)` 的百分号编码把 `/`、`\` 等非允许字符编码为单一路径分量，
/// 这里锁定该 containment 不变量，防止后续重构再次引入穿越。
@Suite("MemoryID 路径穿越防护")
@MainActor
struct MemoryIDTraversalTests {
    private func makeTempStorage() -> (MemoryFileStorage, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-traversal-tests-\(UUID().uuidString)")
        return (MemoryFileStorage(rootURL: url), url)
    }

    private func assertWithinRoot(_ filePath: String, root: URL) {
        let rootPath = root.standardizedFileURL.path
        let standardized = URL(fileURLWithPath: filePath).standardizedFileURL.path
        #expect(standardized.hasPrefix(rootPath + "/"))
        #expect(FileManager.default.fileExists(atPath: standardized))
    }

    @Test("穿越 id 的文件名编码不得保留真实路径分隔符")
    func fileNameEncodesPathSeparators() {
        let encoded = MemoryFileStorage.fileName(forID: "../../../outside")
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("\\"))
        #expect(encoded == "..%2F..%2F..%2Foutside")
    }

    @Test("project 作用域 save 穿越 id 必须落在 Memory 根目录内")
    func saveTraversalIDProjectStaysWithinRoot() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let item = try await storage.save(
            id: "../../../outside", type: .project, name: "N", description: "",
            content: "unexpected", scope: .project, projectPath: "/tmp/proj"
        )
        assertWithinRoot(item.filePath, root: root)
    }

    @Test("global 作用域 save 穿越 id 必须落在 Memory 根目录内")
    func saveTraversalIDGlobalStaysWithinRoot() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let item = try await storage.save(
            id: "../../../outside", type: .user, name: "N", description: "",
            content: "unexpected", scope: .global, projectPath: nil
        )
        assertWithinRoot(item.filePath, root: root)
    }

    @Test("反斜杠与绝对路径 id 不得逃出 Memory 根目录")
    func backslashAndAbsoluteIDStayWithinRoot() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let backslash = try await storage.save(
            id: "..\\..\\outside", type: .project, name: "N", description: "",
            content: "x", scope: .global, projectPath: nil
        )
        let absolute = try await storage.save(
            id: "/etc/passwd", type: .project, name: "N", description: "",
            content: "x", scope: .global, projectPath: nil
        )
        assertWithinRoot(backslash.filePath, root: root)
        assertWithinRoot(absolute.filePath, root: root)
        #expect(!MemoryFileStorage.fileName(forID: "..\\..\\outside").contains("\\"))
        #expect(!MemoryFileStorage.fileName(forID: "/etc/passwd").contains("/"))
    }

    @Test("纯点号 id 不得逃出 Memory 根目录")
    func dotOnlyIDStaysWithinRoot() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let dotdot = try await storage.save(
            id: "..", type: .project, name: "N", description: "",
            content: "x", scope: .global, projectPath: nil
        )
        let dot = try await storage.save(
            id: ".", type: .project, name: "N", description: "",
            content: "x", scope: .global, projectPath: nil
        )
        assertWithinRoot(dotdot.filePath, root: root)
        assertWithinRoot(dot.filePath, root: root)
    }

    @Test("load/delete 穿越 id 仅命中根目录内文件，不触及外部")
    func loadAndDeleteTraversalIDStayContained() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let item = try await storage.save(
            id: "../../../outside", type: .project, name: "N", description: "",
            content: "contained", scope: .project, projectPath: "/tmp/proj"
        )
        assertWithinRoot(item.filePath, root: root)

        let loaded = try await storage.load(
            id: "../../../outside", type: .project, scope: .project, projectPath: "/tmp/proj"
        )
        #expect(loaded?.content == "contained")

        try await storage.delete(id: "../../../outside", scope: .project, projectPath: "/tmp/proj")
        #expect(!FileManager.default.fileExists(atPath: item.filePath))
    }
}
