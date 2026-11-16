import Foundation
import Testing
@testable import PluginSettingGeneral

/// 诊断导出「保存位置就是本轮 archive 本身」的数据丢失回归（#416）。
///
/// ## 复现的缺陷
///
/// `exportDiagnostics()` 生成临时 archive 后注册了
/// `defer { try? FileManager.default.removeItem(at: archive.url) }`。
/// 若用户在 SavePanel 里把保存位置选成**这个临时 archive 本身**，导出流程
/// 结束后该 defer 会把用户刚导出的文件删掉——界面提示「已导出」，文件却没了。
///
/// （`installDiagnosticsArchive` 自 #997 改为 staging+backup 后，即便
/// source==destination 也不会先删源文件；本缺陷的残留点在于无条件清理的 defer。）
///
/// ## 修复
///
/// 保存位置与 archive 同一文件时：跳过复制、直接视为成功，并让 defer **保留**
/// 该文件。判定落在两个纯函数上：`isSameArchiveLocation`（同一文件比较）与
/// `shouldCleanUpTemporaryArchive`（是否清理临时 archive）。
///
/// ## 观测手段
///
/// 用真实临时文件复现 defer 的「判定 + 清理」动作：把
/// `shouldCleanUpTemporaryArchive` 的返回值当作是否 `removeItem` 的依据，
/// 断言用户导出的文件在同名位置下必须存活、在别处/取消时临时文件必须被清理。
@Suite("诊断导出·保存位置即 archive（#416）")
struct DiagnosticsExportSelfLocationTests {

    // MARK: - 不变式 1：导出到 archive 本身必须保留文件

    /// 用户把保存位置选成 archive 本身时，清理判定必须为「保留」，文件不得被删。
    @Test("导出到 archive 本身后文件必须保留（回归 #416）")
    func exportToArchiveItselfKeepsTheFile() throws {
        let fileManager = FileManager.default
        let directory = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: directory) }

        let archive = directory.appendingPathComponent("Lumi-Diagnostics-X.zip")
        try Data("archive-content".utf8).write(to: archive)

        // 用户选择的保存位置就是 archive 本身。
        let destination = archive
        #expect(GeneralSettingsViewModel.isSameArchiveLocation(destination, as: archive))

        // 复现 exportDiagnostics 的 defer：按判定决定是否清理临时 archive。
        if GeneralSettingsViewModel.shouldCleanUpTemporaryArchive(at: archive, exportedTo: destination) {
            try fileManager.removeItem(at: archive)
        }

        #expect(
            fileManager.fileExists(atPath: archive.path),
            "保存位置即 archive 时，导出成果不得被清理 defer 删除"
        )
        #expect(try String(contentsOf: archive, encoding: .utf8) == "archive-content")
    }

    /// 经符号链接目录指向同一 archive 时，也必须识别为同一位置并保留文件。
    @Test("经符号链接指向 archive 本身仍保留文件（回归 #416）")
    func exportToArchiveViaSymlinkKeepsTheFile() throws {
        let fileManager = FileManager.default
        let directory = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: directory) }

        let archive = directory.appendingPathComponent("Lumi-Diagnostics-X.zip")
        try Data("archive-content".utf8).write(to: archive)

        // 另建一个指向同一目录的符号链接，模拟 /tmp 与 /private/tmp 之类等价写法。
        let link = fileManager.temporaryDirectory
            .appendingPathComponent("lumi-diag-link-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createSymbolicLink(at: link, withDestinationURL: directory)
        defer { try? fileManager.removeItem(at: link) }
        let destination = link.appendingPathComponent("Lumi-Diagnostics-X.zip")

        #expect(GeneralSettingsViewModel.isSameArchiveLocation(destination, as: archive))
        if GeneralSettingsViewModel.shouldCleanUpTemporaryArchive(at: archive, exportedTo: destination) {
            try fileManager.removeItem(at: archive)
        }
        #expect(fileManager.fileExists(atPath: archive.path), "符号链接等价位置同样不得删除导出成果")
    }

    // MARK: - 不变式 2：导出到别处 / 取消时仍清理临时 archive

    /// 复制到别处后，临时 archive 必须被清理，目标文件内容完整。
    @Test("导出到别处后清理临时 archive 且目标完整（回归 #416）")
    func exportElsewhereRemovesTemporaryArchive() throws {
        let fileManager = FileManager.default
        let directory = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: directory) }
        let otherDirectory = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: otherDirectory) }

        let archive = directory.appendingPathComponent("Lumi-Diagnostics-X.zip")
        try Data("archive-content".utf8).write(to: archive)
        let destination = otherDirectory.appendingPathComponent("saved.zip")

        #expect(!GeneralSettingsViewModel.isSameArchiveLocation(destination, as: archive))
        try GeneralSettingsViewModel.installDiagnosticsArchive(from: archive, to: destination)
        if GeneralSettingsViewModel.shouldCleanUpTemporaryArchive(at: archive, exportedTo: destination) {
            try fileManager.removeItem(at: archive)
        }

        #expect(try String(contentsOf: destination, encoding: .utf8) == "archive-content")
        #expect(!fileManager.fileExists(atPath: archive.path), "复制到别处后临时 archive 必须被清理")
        #expect(try fileManager.contentsOfDirectory(atPath: otherDirectory.path) == ["saved.zip"])
    }

    /// 取消导出（没有保存位置）时，临时 archive 必须被清理。
    @Test("取消导出后清理临时 archive（回归 #416）")
    func cancelledExportRemovesTemporaryArchive() throws {
        let fileManager = FileManager.default
        let directory = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: directory) }

        let archive = directory.appendingPathComponent("Lumi-Diagnostics-X.zip")
        try Data("archive-content".utf8).write(to: archive)

        #expect(GeneralSettingsViewModel.shouldCleanUpTemporaryArchive(at: archive, exportedTo: nil))
        if GeneralSettingsViewModel.shouldCleanUpTemporaryArchive(at: archive, exportedTo: nil) {
            try fileManager.removeItem(at: archive)
        }
        #expect(!fileManager.fileExists(atPath: archive.path), "取消导出后不得留下临时 archive")
    }

    // MARK: - 不变式 3：同一文件比较的健壮性

    /// 同一文件的各种等价路径写法必须判为同一位置；不同文件必须判为不同。
    @Test("同一 archive 的路径变体识别与区分（回归 #416）")
    func sameArchiveLocationHandlesPathRepresentations() throws {
        let fileManager = FileManager.default
        let directory = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: directory) }

        let archive = directory.appendingPathComponent("Lumi-Diagnostics-X.zip")
        try Data("x".utf8).write(to: archive)

        // 等价写法：直接路径字符串、含真实子目录的 .. 回退。
        let viaPathString = URL(fileURLWithPath: archive.path)
        #expect(GeneralSettingsViewModel.isSameArchiveLocation(viaPathString, as: archive))
        let sub = directory.appendingPathComponent("sub", isDirectory: true)
        try fileManager.createDirectory(at: sub, withIntermediateDirectories: true)
        let viaDotDot = sub.appendingPathComponent("..").appendingPathComponent("Lumi-Diagnostics-X.zip")
        #expect(GeneralSettingsViewModel.isSameArchiveLocation(viaDotDot, as: archive))

        // 不同文件名 / 不同目录 → 不是同一位置。
        let differentName = directory.appendingPathComponent("Lumi-Diagnostics-Y.zip")
        #expect(!GeneralSettingsViewModel.isSameArchiveLocation(differentName, as: archive))
        let otherDirectory = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: otherDirectory) }
        let differentDirectory = otherDirectory.appendingPathComponent("Lumi-Diagnostics-X.zip")
        #expect(!GeneralSettingsViewModel.isSameArchiveLocation(differentDirectory, as: archive))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-diag-self-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}