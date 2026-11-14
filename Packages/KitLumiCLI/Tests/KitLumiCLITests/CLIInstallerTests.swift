import Foundation
import Testing
@testable import KitLumiCLI

/// `CLIInstaller` 的安装 / 卸载 / 状态查询测试。
@Suite("CLIInstaller")
struct CLIInstallerTests {

    /// 隔离的临时目录，扮演安装目标目录。
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitlumicli-installer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("安装后脚本存在且可执行")
    func installCreatesExecutableScript() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = CLIInstallTarget(
            directory: directory,
            isOnPath: true,
            isWritable: true
        )

        let outcome = CLIInstaller.install(
            target: target,
            urlScheme: "lumi",
            appPath: "/Applications/Lumi.app",
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        guard case .installed(let installed) = outcome else {
            Issue.record("期望安装成功，实际为 \(outcome)")
            return
        }
        #expect(installed.directory.path == directory.standardizedFileURL.path)

        let scriptURL = directory.appendingPathComponent("lumi")
        #expect(FileManager.default.fileExists(atPath: scriptURL.path))
        #expect(FileManager.default.isExecutableFile(atPath: scriptURL.path))
    }

    @Test("安装到不在 PATH 中的目录时返回 installedButNotOnPath")
    func installReportsNotOnPath() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = CLIInstallTarget(
            directory: directory,
            isOnPath: false,
            isWritable: true
        )

        let outcome = CLIInstaller.install(
            target: target,
            pathEntries: [],
            environment: ["HOME": "/nonexistent-home"]
        )

        guard case .installedButNotOnPath = outcome else {
            Issue.record("期望 installedButNotOnPath，实际为 \(outcome)")
            return
        }
    }

    @Test("写入不可写目录时安装失败")
    func installFailsForNonWritableTarget() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = CLIInstallTarget(
            directory: directory,
            isOnPath: true,
            isWritable: false
        )

        let outcome = CLIInstaller.install(
            target: target,
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        guard case .failed = outcome else {
            Issue.record("期望失败，实际为 \(outcome)")
            return
        }
    }

    @Test("安装到不存在的目录时自动创建")
    func installCreatesMissingDirectory() throws {
        let parent = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let directory = parent.appendingPathComponent("nested/bin", isDirectory: true)
        let target = CLIInstallTarget(
            directory: directory,
            isOnPath: true,
            isWritable: true
        )

        let outcome = CLIInstaller.install(
            target: target,
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        guard case .installed = outcome else {
            Issue.record("期望安装成功，实际为 \(outcome)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("未安装时状态为未安装")
    func statusReportsNotInstalled() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let status = CLIInstaller.status(
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        #expect(!status.isInstalled)
        #expect(status.installedPath == nil)
    }

    @Test("安装后状态能查到脚本路径")
    func statusFindsInstalledScript() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = CLIInstallTarget(
            directory: directory,
            isOnPath: true,
            isWritable: true
        )
        _ = CLIInstaller.install(
            target: target,
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        let status = CLIInstaller.status(
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        #expect(status.isInstalled)
        let path = try #require(status.installedPath)
        #expect(path.lastPathComponent == "lumi")
        #expect(status.isOnPath)
    }

    @Test("卸载后脚本被删除")
    func uninstallRemovesScript() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = CLIInstallTarget(
            directory: directory,
            isOnPath: true,
            isWritable: true
        )
        _ = CLIInstaller.install(
            target: target,
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        let removed = CLIInstaller.uninstall(
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        #expect(removed)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("lumi").path))
    }

    @Test("未安装时卸载也算成功")
    func uninstallSucceedsWhenNotInstalled() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let removed = CLIInstaller.uninstall(
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        #expect(removed)
    }

    @Test("安装的脚本内容包含 LUMI_APP 与 open-project 协议")
    func installedScriptContentIsExpected() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = CLIInstallTarget(
            directory: directory,
            isOnPath: true,
            isWritable: true
        )
        _ = CLIInstaller.install(
            target: target,
            urlScheme: "lumi",
            appPath: "/Applications/Lumi.app",
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        let scriptURL = directory.appendingPathComponent("lumi")
        let contents = try String(contentsOf: scriptURL, encoding: .utf8)

        #expect(contents.contains("LUMI_APP"))
        #expect(contents.contains("://finder/open-project?path="))
        #expect(contents.contains("/Applications/Lumi.app"))
    }

    /// 在指定 URL 写入一个可执行脚本，扮演用户已有的同名第三方程序。
    private func writeExecutable(at url: URL, contents: String) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: url.path
        )
    }

    @Test("安装遇到同名第三方程序时拒绝覆盖，原内容不得丢失")
    func installPreservesUnrelatedExecutable() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let scriptURL = directory.appendingPathComponent("lumi")
        let original = "#!/bin/sh\necho unrelated\n"
        try writeExecutable(at: scriptURL, contents: original)

        let target = CLIInstallTarget(
            directory: directory,
            isOnPath: true,
            isWritable: true
        )
        let outcome = CLIInstaller.install(
            target: target,
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        guard case .failed = outcome else {
            Issue.record("期望拒绝覆盖第三方程序，实际为 \(outcome)")
            return
        }
        #expect(try String(contentsOf: scriptURL, encoding: .utf8) == original)
        #expect(FileManager.default.isExecutableFile(atPath: scriptURL.path))
    }

    @Test("卸载不得删除同名第三方程序")
    func uninstallPreservesUnrelatedExecutable() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let scriptURL = directory.appendingPathComponent("lumi")
        let original = "#!/bin/sh\necho unrelated\n"
        try writeExecutable(at: scriptURL, contents: original)

        let removed = CLIInstaller.uninstall(
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        #expect(removed)
        #expect(FileManager.default.fileExists(atPath: scriptURL.path))
        #expect(try String(contentsOf: scriptURL, encoding: .utf8) == original)
    }

    @Test("状态查询不把同名第三方程序当作已安装")
    func statusDoesNotReportUnrelatedExecutableAsInstalled() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let scriptURL = directory.appendingPathComponent("lumi")
        try writeExecutable(at: scriptURL, contents: "#!/bin/sh\necho unrelated\n")

        let status = CLIInstaller.status(
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        #expect(!status.isInstalled)
        #expect(status.installedPath == nil)
    }

    @Test("重复安装可更新已有的 Lumi 脚本（升级路径不被破坏）")
    func installUpdatesExistingLumiScript() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = CLIInstallTarget(
            directory: directory,
            isOnPath: true,
            isWritable: true
        )
        _ = CLIInstaller.install(
            target: target,
            urlScheme: "lumi",
            appPath: "/Applications/Lumi.app",
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        let outcome = CLIInstaller.install(
            target: target,
            urlScheme: "lumi",
            appPath: "/Users/test/Applications/Lumi.app",
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        guard case .installed = outcome else {
            Issue.record("期望更新已有 Lumi 脚本成功，实际为 \(outcome)")
            return
        }
        let scriptURL = directory.appendingPathComponent("lumi")
        let contents = try String(contentsOf: scriptURL, encoding: .utf8)
        #expect(contents.contains("/Users/test/Applications/Lumi.app"))
        #expect(FileManager.default.isExecutableFile(atPath: scriptURL.path))
    }

    @Test("旧版 Lumi 脚本仍被识别为已安装并可卸载（向后兼容）")
    func legacyLumiScriptIsStillRecognized() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let scriptURL = directory.appendingPathComponent("lumi")
        // 旧版脚本只有中文签名，没有新的 ownershipMarker。
        let legacy = "#!/bin/sh\n# 由 Lumi.app 的「设置 → 通用 → 命令行工具」自动安装。\necho legacy\n"
        try writeExecutable(at: scriptURL, contents: legacy)

        let status = CLIInstaller.status(
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )
        #expect(status.isInstalled)
        #expect(status.installedPath?.lastPathComponent == "lumi")

        let removed = CLIInstaller.uninstall(
            pathEntries: [directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )
        #expect(removed)
        #expect(!FileManager.default.fileExists(atPath: scriptURL.path))
    }
}
