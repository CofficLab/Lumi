import Foundation
import Testing
@testable import AppManagerPlugin

/// Regression coverage for #796: the directory size computation passed
/// `.skipsHiddenFiles`, so dotfiles and their descendants inside an `.app`
/// bundle were excluded and app sizes were systematically too small; the
/// wrong values were also written into the cache and reused.
struct AppSizeCalculationTests {

    @Test
    func sizeIncludesHiddenFilesInsideBundle() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-796-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let bundle = base.appendingPathComponent("Sample.app", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bundle.appendingPathComponent("Contents/Resources"),
            withIntermediateDirectories: true
        )
        let visibleData = Data(repeating: 0x41, count: 4096)
        let hiddenData = Data(repeating: 0x42, count: 2048)
        try visibleData.write(to: bundle.appendingPathComponent("Contents/Resources/visible.bin"))
        try hiddenData.write(to: bundle.appendingPathComponent("Contents/Resources/.payload"))

        let size = await AppService.calculateSize(for: bundle)

        // 隐藏文件同样真实占用磁盘空间：体积必须是可见 + 隐藏内容之和。
        #expect(size == Int64(visibleData.count + hiddenData.count))
    }

    @Test
    func sizeIncludesDescendantsOfHiddenDirectories() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-796-hidden-dir-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let bundle = base.appendingPathComponent("Sample.app", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bundle.appendingPathComponent("Contents/.cache/nested"),
            withIntermediateDirectories: true
        )
        let deepData = Data(repeating: 0x43, count: 1024)
        try deepData.write(to: bundle.appendingPathComponent("Contents/.cache/nested/deep.bin"))

        let size = await AppService.calculateSize(for: bundle)

        #expect(size == Int64(deepData.count))
    }
}
