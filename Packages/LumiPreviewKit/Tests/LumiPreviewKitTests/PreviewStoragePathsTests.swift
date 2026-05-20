import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("PreviewStoragePaths")
struct PreviewStoragePathsTests {

    @Test("插件根目录下包含各预览子目录")
    func pluginLayoutDirectories() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreviewStoragePathsTests-\(UUID().uuidString)", isDirectory: true)
        let paths = LumiPreviewFacade.PreviewStoragePaths(rootDirectory: root)
        try paths.ensureDirectoriesExist()

        #expect(paths.previewEntryCacheDirectory.lastPathComponent == "preview-entry-cache")
        #expect(paths.entryCacheDirectory.lastPathComponent == "entry-cache")
        #expect(paths.compileCommandCacheDirectory.lastPathComponent == "compile-command-cache")
        #expect(paths.framesDirectory.lastPathComponent == "frames")
        #expect(paths.sharedMemoryDirectory.lastPathComponent == "shared-memory")
        #expect(paths.workDirectory.lastPathComponent == "work")
        #expect(FileManager.default.fileExists(atPath: paths.framesDirectory.path))

        defer { try? FileManager.default.removeItem(at: root) }
    }

    @Test("configure 后默认路径读取插件目录")
    func configureUpdatesGlobalPaths() throws {
        let previous = LumiPreviewFacade.PreviewStorage.paths
        defer { LumiPreviewFacade.PreviewStorage.configure(previous) }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreviewStorageConfigureTests-\(UUID().uuidString)", isDirectory: true)
        let configured = LumiPreviewFacade.PreviewStoragePaths(rootDirectory: root)
        try configured.ensureDirectoriesExist()
        LumiPreviewFacade.PreviewStorage.configure(configured)

        #expect(LumiPreviewFacade.PreviewStorage.paths.rootDirectory == root)
        #expect(LumiPreviewFacade.PreviewStorage.paths.framesDirectory == configured.framesDirectory)

        defer { try? FileManager.default.removeItem(at: root) }
    }
}
