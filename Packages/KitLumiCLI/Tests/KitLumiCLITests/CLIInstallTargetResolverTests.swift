import Foundation
import Testing
@testable import KitLumiCLI

/// `CLIInstallTargetResolver` 的候选目录挑选测试。
@Suite("CLIInstallTargetResolver")
struct CLIInstallTargetResolverTests {

    /// 临时目录，用于构造隔离的候选目录。
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitlumicli-resolver-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("PATH 中已存在且可写的目录排在最前")
    func prefersWritablePathDirectory() throws {
        let onPath = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: onPath) }

        let candidates = CLIInstallTargetResolver.candidates(
            pathEntries: [onPath.path, "/usr/bin"],
            environment: ["HOME": "/nonexistent-home"]
        )

        let first = try #require(candidates.first)
        #expect(first.directory.standardizedFileURL.path == onPath.standardizedFileURL.path)
        #expect(first.isOnPath)
        #expect(first.isWritable)
    }

    @Test("不可写的 PATH 目录被排除")
    func excludesNonWritablePathDirectory() throws {
        let locked = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: locked) }
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o500))],
            ofItemAtPath: locked.path
        )

        let candidates = CLIInstallTargetResolver.candidates(
            pathEntries: [locked.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        #expect(!candidates.contains { $0.directory.path == locked.path })
    }

    @Test("PATH 中不存在的目录被排除")
    func excludesMissingPathDirectory() {
        let candidates = CLIInstallTargetResolver.candidates(
            pathEntries: ["/nonexistent/dir/for/lumi/cli"],
            environment: ["HOME": "/nonexistent-home"]
        )

        #expect(!candidates.contains { $0.directory.path == "/nonexistent/dir/for/lumi/cli" })
    }

    @Test("~/.local/bin 始终作为兜底候选")
    func alwaysOffersUserLocalBin() {
        let candidates = CLIInstallTargetResolver.candidates(
            pathEntries: [],
            environment: ["HOME": "/tmp/fake-home-for-lumi-cli"]
        )

        let userTarget = candidates.first {
            $0.directory.path.hasSuffix(CLIInstallTargetResolver.userDirectoryName)
        }
        let target = try? #require(userTarget)
        #expect(target != nil)
    }

    @Test("没有 HOME 时不产生用户级候选")
    func omitsUserTargetWithoutHome() {
        let candidates = CLIInstallTargetResolver.candidates(
            pathEntries: [],
            environment: [:]
        )

        #expect(!candidates.contains {
            $0.directory.path.hasSuffix(CLIInstallTargetResolver.userDirectoryName)
        })
    }

    @Test("bestTarget 优先返回已在 PATH 中的可写目录")
    func bestTargetPrefersOnPath() throws {
        let onPath = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: onPath) }

        let best = CLIInstallTargetResolver.bestTarget(
            pathEntries: ["/usr/bin", onPath.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        let target = try #require(best)
        #expect(target.directory.standardizedFileURL.path == onPath.standardizedFileURL.path)
        #expect(target.isOnPath)
    }

    @Test("重复的 PATH 条目只产生一个候选")
    func deduplicatesPathEntries() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let candidates = CLIInstallTargetResolver.candidates(
            pathEntries: [directory.path, directory.path, directory.path],
            environment: ["HOME": "/nonexistent-home"]
        )

        let matching = candidates.filter {
            $0.directory.standardizedFileURL.path == directory.standardizedFileURL.path
        }
        #expect(matching.count == 1)
    }

    @Test("scriptURL 指向目标目录下的命令名")
    func scriptURLPointsIntoDirectory() {
        let target = CLIInstallTarget(
            directory: URL(fileURLWithPath: "/tmp/bin"),
            isOnPath: true,
            isWritable: true
        )

        #expect(target.scriptURL(for: "lumi").path == "/tmp/bin/lumi")
    }
}
