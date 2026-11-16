import Foundation
import Testing

@testable import PluginAppIconDesigner

/// 回归 issue #1291：Xcode `.icon` 导出改为 async 管线后，lint、PNG 压缩、
/// manifest 编码与原子文件写入都在后台执行，主 actor 只做 ImageRenderer 栅格化，
/// 导出结果仍须完整正确。
@Suite("IconComposerExportService off-main export")
struct IconComposerExportOffMainTests {

    @Test("async export produces a complete icon set off the main actor")
    @MainActor
    func exportsDocumentOffMain() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icon-export-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let document = IconDocument(title: "Export Test", width: 512, height: 512)
        let result = try await IconComposerExportService().export(
            document: document,
            outputDirectory: directory
        )

        #expect(FileManager.default.fileExists(atPath: result.iconURL.path))
        let artwork = result.iconURL.appendingPathComponent("Assets/Artwork.png")
        let manifest = result.iconURL.appendingPathComponent("icon.json")
        #expect(FileManager.default.fileExists(atPath: artwork.path))
        #expect(FileManager.default.fileExists(atPath: manifest.path))
        #expect(try Data(contentsOf: artwork).isEmpty == false)
        #expect(try Data(contentsOf: manifest).isEmpty == false)
    }
}