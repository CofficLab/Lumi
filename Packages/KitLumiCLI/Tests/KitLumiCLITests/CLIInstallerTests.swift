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
}
