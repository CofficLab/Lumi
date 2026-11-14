import Foundation
import Testing
@testable import PluginPrototypeDesigner

/// 回归覆盖 issue #427：用户选中的导出目录可能尚不存在，
/// 安装阶段必须先创建目录（含中间目录）再 moveItem，否则首张图片就失败、整批回滚。
/// 同时锁定事务性安装的既有一旦失败必回滚、覆盖前先备份语义。
@Suite("PrototypeExport 安装")
struct PrototypeExportInstallTests {

    @Test("导出目录尚不存在时先创建再安装成功")
    func installsIntoDirectoryThatDoesNotExistYet() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let staging = try makeStaging(in: root)
        // 用户新建的多级导出目录，尚不存在。
        let output = root.appendingPathComponent("new-export/sub", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: output.path))

        let first = try stageFile("png-1", in: staging, name: "rendered-0.png")
        let second = try stageFile("png-2", in: staging, name: "rendered-1.png")
        let staged = [
            ExportPrototypeTool.StagedExport(
                stagedURL: first,
                destinationURL: output.appendingPathComponent("01-home.png"),
                summary: "s1"
            ),
            ExportPrototypeTool.StagedExport(
                stagedURL: second,
                destinationURL: output.appendingPathComponent("02-detail.png"),
                summary: "s2"
            ),
        ]

        try ExportPrototypeTool.installStagedExports(
            staged, outputDirectory: output,
            backupDirectory: staging.appendingPathComponent("backups", isDirectory: true)
        )

        #expect(FileManager.default.fileExists(atPath: output.path))
        #expect(try String(contentsOf: output.appendingPathComponent("01-home.png"), encoding: .utf8) == "png-1")
        #expect(try String(contentsOf: output.appendingPathComponent("02-detail.png"), encoding: .utf8) == "png-2")
    }

    @Test("中途失败时回滚已安装文件，不留半成品")
    func rollsBackWhenAnInstallStepFails() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let staging = try makeStaging(in: root)
        let output = root.appendingPathComponent("export", isDirectory: true)

        let first = try stageFile("png-1", in: staging, name: "rendered-0.png")
        let missing = staging.appendingPathComponent("does-not-exist.png")
        let firstDest = output.appendingPathComponent("01-home.png")
        let secondDest = output.appendingPathComponent("02-detail.png")
        let staged = [
            ExportPrototypeTool.StagedExport(stagedURL: first, destinationURL: firstDest, summary: "s1"),
            ExportPrototypeTool.StagedExport(stagedURL: missing, destinationURL: secondDest, summary: "s2"),
        ]

        #expect(throws: (any Error).self) {
            try ExportPrototypeTool.installStagedExports(
                staged, outputDirectory: output,
                backupDirectory: staging.appendingPathComponent("backups", isDirectory: true)
            )
        }
        // 第一张曾安装成功，但失败后必须被回滚删除。
        #expect(!FileManager.default.fileExists(atPath: firstDest.path))
        #expect(!FileManager.default.fileExists(atPath: secondDest.path))
    }

    @Test("覆盖已有文件时先备份再替换")
    func backsUpAndReplacesExistingFile() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let staging = try makeStaging(in: root)
        let output = root.appendingPathComponent("export", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let dest = output.appendingPathComponent("01-home.png")
        try Data("user-old".utf8).write(to: dest)

        let replacement = try stageFile("png-new", in: staging, name: "rendered-0.png")
        let staged = [ExportPrototypeTool.StagedExport(stagedURL: replacement, destinationURL: dest, summary: "s1")]
        let backups = staging.appendingPathComponent("backups", isDirectory: true)

        try ExportPrototypeTool.installStagedExports(staged, outputDirectory: output, backupDirectory: backups)

        #expect(try String(contentsOf: dest, encoding: .utf8) == "png-new")
        #expect(try String(contentsOf: backups.appendingPathComponent("0.png"), encoding: .utf8) == "user-old")
    }

    // MARK: - Helpers

    private func makeTempRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("prototype-install-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeStaging(in root: URL) throws -> URL {
        let staging = root.appendingPathComponent("staging", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        return staging
    }

    private func stageFile(_ content: String, in staging: URL, name: String) throws -> URL {
        let url = staging.appendingPathComponent(name)
        try Data(content.utf8).write(to: url, options: .atomic)
        return url
    }
}