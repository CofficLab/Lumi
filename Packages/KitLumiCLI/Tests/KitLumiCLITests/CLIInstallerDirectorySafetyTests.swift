import Foundation
import Testing
@testable import KitLumiCLI

/// `CLIInstaller` 对同名目录的安全保护（回归 #490）。
///
/// ## 回归背景
///
/// macOS 上可搜索目录也会被 `FileManager.isExecutableFile` 判为可执行。原先
/// `installedScriptURL` 只凭可执行性认定「已安装脚本」，于是名为 `lumi` 的目录
/// 被当成脚本，`uninstall` 把该 URL 直接交给 `FileManager.removeItem`——对目录
/// 而言这是递归删除，整个 `lumi` 目录及其内容被删光。修复：状态查询与卸载都必须
/// 显式确认目标不是目录（`fileExists(isDirectory:)`，解析符号链接），目录一律不认作
/// 脚本、绝不删除。
@Suite("CLIInstaller 目录安全")
struct CLIInstallerDirectorySafetyTests {

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitlumicli-dir490-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 在 bin 目录下创建一个名为 lumi 的目录，内含 keep 文件，扮演误删目标。
    private func makeLumiDirectoryWithKeep(in bin: URL) throws -> (lumi: URL, keep: URL) {
        let lumi = bin.appendingPathComponent("lumi", isDirectory: true)
        try FileManager.default.createDirectory(at: lumi, withIntermediateDirectories: true)
        let keep = lumi.appendingPathComponent("keep")
        try "precious".write(to: keep, atomically: true, encoding: .utf8)
        return (lumi, keep)
    }

    private func installRealScript(in bin: URL) {
        let target = CLIInstallTarget(directory: bin, isOnPath: true, isWritable: true)
        _ = CLIInstaller.install(
            target: target,
            urlScheme: "lumi",
            appPath: "/Applications/Lumi.app",
            pathEntries: [bin.path],
            environment: ["HOME": "/nonexistent-home"]
        )
    }

    // MARK: - 目录不被认作脚本、不被删除

    @Test("状态查询不把同名目录当作已安装（回归 #490）")
    func statusDoesNotReportDirectoryAsInstalled() throws {
        let bin = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: bin) }
        let (lumi, _) = try makeLumiDirectoryWithKeep(in: bin)
        // 前提：目录确实被 isExecutableFile 判为可执行（否则用例失去意义）。
        #expect(FileManager.default.isExecutableFile(atPath: lumi.path))

        let status = CLIInstaller.status(
            pathEntries: [bin.path],
            environment: ["HOME": "/nonexistent-home"]
        )
        #expect(!status.isInstalled)
        #expect(status.installedPath == nil)
    }

    @Test("卸载不得递归删除同名目录及其内容（回归 #490）")
    func uninstallPreservesDirectoryAndItsContents() throws {
        let bin = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: bin) }
        let (lumi, keep) = try makeLumiDirectoryWithKeep(in: bin)

        let removed = CLIInstaller.uninstall(
            pathEntries: [bin.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        // 目录不是脚本，卸载视为「无可卸载」成功，但目录与内容必须原样保留。
        #expect(removed)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: lumi.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
        #expect(FileManager.default.fileExists(atPath: keep.path))
        #expect(try String(contentsOf: keep, encoding: .utf8) == "precious")
    }

    @Test("installedScriptURL 对同名目录返回 nil（回归 #490）")
    func installedScriptURLReturnsNilForDirectory() throws {
        let bin = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: bin) }
        _ = try makeLumiDirectoryWithKeep(in: bin)

        let url = CLIInstaller.installedScriptURL(
            pathEntries: [bin.path],
            environment: ["HOME": "/nonexistent-home"]
        )
        #expect(url == nil)
    }

    @Test("卸载不得删除指向目录的符号链接，目标目录内容保留（回归 #490）")
    func uninstallPreservesSymlinkToDirectory() throws {
        let bin = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: bin) }
        let realDir = bin.appendingPathComponent("realdir", isDirectory: true)
        try FileManager.default.createDirectory(at: realDir, withIntermediateDirectories: true)
        let keep = realDir.appendingPathComponent("keep")
        try "precious".write(to: keep, atomically: true, encoding: .utf8)
        let link = bin.appendingPathComponent("lumi")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: realDir)

        let status = CLIInstaller.status(
            pathEntries: [bin.path],
            environment: ["HOME": "/nonexistent-home"]
        )
        #expect(!status.isInstalled)

        let removed = CLIInstaller.uninstall(
            pathEntries: [bin.path],
            environment: ["HOME": "/nonexistent-home"]
        )
        #expect(removed)
        #expect(FileManager.default.fileExists(atPath: keep.path))
        #expect(try String(contentsOf: keep, encoding: .utf8) == "precious")
    }

    // MARK: - 普通文件 / 合法符号链接不受影响（无回归）

    @Test("状态查询仍能查到真实安装的 Lumi 脚本")
    func statusStillFindsRealLumiScript() throws {
        let bin = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: bin) }
        installRealScript(in: bin)

        let status = CLIInstaller.status(
            pathEntries: [bin.path],
            environment: ["HOME": "/nonexistent-home"]
        )
        #expect(status.isInstalled)
        #expect(status.installedPath?.lastPathComponent == "lumi")
    }

    @Test("卸载仍能删除真实安装的 Lumi 脚本")
    func uninstallStillRemovesRealLumiScript() throws {
        let bin = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: bin) }
        installRealScript(in: bin)

        let removed = CLIInstaller.uninstall(
            pathEntries: [bin.path],
            environment: ["HOME": "/nonexistent-home"]
        )
        #expect(removed)
        #expect(!FileManager.default.fileExists(atPath: bin.appendingPathComponent("lumi").path))
    }

    @Test("指向真实 Lumi 脚本的符号链接仍被识别为已安装")
    func symlinkToRealLumiScriptIsStillRecognized() throws {
        let bin = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: bin) }
        let realBin = bin.appendingPathComponent("realbin", isDirectory: true)
        try FileManager.default.createDirectory(at: realBin, withIntermediateDirectories: true)
        installRealScript(in: realBin)
        let link = bin.appendingPathComponent("lumi")
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: realBin.appendingPathComponent("lumi")
        )

        let status = CLIInstaller.status(
            pathEntries: [bin.path],
            environment: ["HOME": "/nonexistent-home"]
        )
        #expect(status.isInstalled)
        #expect(status.installedPath?.lastPathComponent == "lumi")
    }
}