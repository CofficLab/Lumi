import Foundation
import KitPrototype
import Testing
@testable import PluginPrototypeDesigner

/// 导出文件名与冲突检测：同名文件必须能被识别出来，不能被静默覆盖。
@Suite("PrototypeExportNaming")
struct PrototypeExportNamingTests {

    private func makeProject(screenIDs: [String]) -> PrototypeProject {
        let screens = screenIDs.enumerated().map { index, id in
            PrototypeScreen(
                id: id,
                title: id,
                order: index,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        return PrototypeProject(
            id: "demo",
            title: "Demo",
            style: .hiFi,
            device: PrototypeDeviceKind.iPhone15Pro.preset!,
            screens: screens
        )
    }

    @Test("文件名按顺序编号")
    func filenamesAreOrderedAndNumbered() {
        let project = makeProject(screenIDs: ["home", "detail"])
        let names = PrototypeExportNaming.filenames(for: project)

        #expect(names == ["01-home.png", "02-detail.png"])
    }

    @Test("目标目录为空时没有冲突")
    func noConflictsInEmptyDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("prototype-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let project = makeProject(screenIDs: ["home", "detail"])
        let conflicts = PrototypeExportNaming.existingConflicts(
            in: directory,
            filenames: PrototypeExportNaming.filenames(for: project)
        )

        #expect(conflicts.isEmpty)
    }

    @Test("已存在的同名文件被识别为冲突")
    func detectsExistingFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("prototype-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // 预置一个用户自己的同名文件。
        try Data("user content".utf8).write(
            to: directory.appendingPathComponent("01-home.png")
        )

        let project = makeProject(screenIDs: ["home", "detail"])
        let conflicts = PrototypeExportNaming.existingConflicts(
            in: directory,
            filenames: PrototypeExportNaming.filenames(for: project)
        )

        #expect(conflicts == ["01-home.png"])
    }

    @Test("未参与导出的同名文件不算冲突")
    func ignoresUnrelatedFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("prototype-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data("user content".utf8).write(
            to: directory.appendingPathComponent("99-other.png")
        )

        let project = makeProject(screenIDs: ["home"])
        let conflicts = PrototypeExportNaming.existingConflicts(
            in: directory,
            filenames: PrototypeExportNaming.filenames(for: project)
        )

        #expect(conflicts.isEmpty)
    }
}
