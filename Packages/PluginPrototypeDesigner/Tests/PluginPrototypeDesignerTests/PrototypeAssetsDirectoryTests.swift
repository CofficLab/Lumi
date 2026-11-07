import Foundation
import KitPrototype
import Testing
@testable import PluginPrototypeDesigner

/// 素材导入必须要求目标项目已存在，且不得留下孤儿目录。
@Suite("PrototypeDocumentStore 素材目录")
struct PrototypeAssetsDirectoryTests {

    private func makeStore() -> (PrototypeDocumentStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("prototype-assets-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (PrototypeDocumentStore(), root)
    }

    @Test("项目不存在时素材目录请求抛出 notFound 且不创建目录")
    func missingProjectThrowsWithoutCreatingDirectory() throws {
        let (store, root) = makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(throws: PrototypeStoreError.self) {
            try store.existingProjectAssetsDirectoryURL(
                storagePath: root.path,
                projectSlug: "missing-project"
            )
        }

        // 关键：不能留下任何目录，否则会占住 slug 让后续创建项目失败。
        let projectDirectory = root
            .appendingPathComponent("prototype", isDirectory: true)
            .appendingPathComponent("missing-project", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: projectDirectory.path))
    }

    @Test("项目不存在时导入素材失败且 slug 仍可被创建")
    func missingProjectDoesNotBlockLaterCreation() throws {
        let (store, root) = makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let slug = "typo-project"
        #expect(throws: PrototypeStoreError.self) {
            try store.existingProjectAssetsDirectoryURL(
                storagePath: root.path,
                projectSlug: slug
            )
        }

        // 之后的项目创建必须仍然成功。
        let project = try store.createProject(
            storagePath: root.path,
            slug: slug,
            title: "Typo",
            style: .hiFi,
            device: PrototypeDeviceKind.iPhone15Pro.preset!
        )
        #expect(project.id == slug)
    }

    @Test("项目存在时返回其素材目录")
    func existingProjectReturnsAssetsDirectory() throws {
        let (store, root) = makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try store.createProject(
            storagePath: root.path,
            slug: "real-project",
            title: "Real",
            style: .hiFi,
            device: PrototypeDeviceKind.iPhone15Pro.preset!
        )

        let assets = try store.existingProjectAssetsDirectoryURL(
            storagePath: root.path,
            projectSlug: "real-project"
        )
        #expect(assets.lastPathComponent == "assets")
        #expect(FileManager.default.fileExists(atPath: assets.path))
    }
}
