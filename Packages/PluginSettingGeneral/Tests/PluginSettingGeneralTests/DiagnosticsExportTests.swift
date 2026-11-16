import Foundation
import Testing
@testable import PluginSettingGeneral

@Suite("诊断导出")
struct DiagnosticsExportTests {

    @Test @MainActor func failedOverwriteKeepsExistingFile() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            try? fileManager.removeItem(at: directory)
        }

        let destination = directory.appendingPathComponent("old.zip")
        try Data("keep-me".utf8).write(to: destination)
        let source = fileManager.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).zip")
        try Data("new-archive".utf8).write(to: source)
        defer {
            try? fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: source.path)
            try? fileManager.removeItem(at: source)
        }

        // 源文件不可读：复制阶段必然失败，模拟空间不足 / I/O 错误。
        try fileManager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: source.path)

        #expect(throws: (any Error).self) {
            try GeneralSettingsViewModel.installDiagnosticsArchive(from: source, to: destination)
        }

        #expect(
            try String(contentsOf: destination, encoding: .utf8) == "keep-me",
            "导出失败后原有文件必须原样保留"
        )
        #expect(
            try fileManager.contentsOfDirectory(atPath: directory.path) == ["old.zip"],
            "失败路径不得留下临时文件或备份文件"
        )
    }

    @Test @MainActor func successfulOverwriteReplacesDestinationWithoutLeftovers() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let destination = directory.appendingPathComponent("old.zip")
        try Data("keep-me".utf8).write(to: destination)
        let source = fileManager.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).zip")
        try Data("new-archive".utf8).write(to: source)
        defer { try? fileManager.removeItem(at: source) }

        try GeneralSettingsViewModel.installDiagnosticsArchive(from: source, to: destination)

        #expect(try String(contentsOf: destination, encoding: .utf8) == "new-archive")
        #expect(
            try fileManager.contentsOfDirectory(atPath: directory.path) == ["old.zip"],
            "成功后不得留下临时文件或备份文件"
        )
    }

    @Test @MainActor func installsIntoEmptyDestination() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let destination = directory.appendingPathComponent("new.zip")
        let source = fileManager.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).zip")
        try Data("new-archive".utf8).write(to: source)
        defer { try? fileManager.removeItem(at: source) }

        try GeneralSettingsViewModel.installDiagnosticsArchive(from: source, to: destination)

        #expect(try String(contentsOf: destination, encoding: .utf8) == "new-archive")
    }

    @Test func installRunsOffMain() async throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let destination = directory.appendingPathComponent("old.zip")
        try Data("keep-me".utf8).write(to: destination)
        let source = fileManager.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).zip")
        try Data("new-archive".utf8).write(to: source)
        defer { try? fileManager.removeItem(at: source) }

        let flag = ThreadFlag()
        try await Task.detached(priority: .userInitiated) {
            try Self.runInstallOffMain(flag: flag, from: source, to: destination)
        }.value

        #expect(flag.value == false, "归档安装必须在非主线程执行")
        #expect(try String(contentsOf: destination, encoding: .utf8) == "new-archive")
        #expect(
            try fileManager.contentsOfDirectory(atPath: directory.path) == ["old.zip"],
            "成功后不得留下临时文件或备份文件"
        )
    }

    /// 同步辅助函数：记录当前线程并调用生产安装逻辑。
    ///
    /// `Thread.isMainThread` 在 async 上下文不可用，必须放在同步函数里。
    private static func runInstallOffMain(flag: ThreadFlag, from source: URL, to destination: URL) throws {
        flag.value = Thread.isMainThread
        try GeneralSettingsViewModel.installDiagnosticsArchive(from: source, to: destination)
    }
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}
