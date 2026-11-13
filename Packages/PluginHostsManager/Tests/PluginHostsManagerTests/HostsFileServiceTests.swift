import Foundation
import Testing
@testable import PluginHostsManager

@Suite("Hosts file service")
@MainActor
struct HostsFileServiceTests {
    @Test("reads and backs up an injected hosts file")
    func readsAndBacksUpHostsFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("hosts")
        let backupDirectory = root.appendingPathComponent("backup", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let backup = backupDirectory.appendingPathComponent("hosts")
        let content = "# local hosts\n127.0.0.1 app.test\n"
        try content.write(to: source, atomically: true, encoding: .utf8)
        let service = HostsFileService(hostsPath: source.path)

        #expect(try await service.readHosts() == content)
        try service.backupHosts(to: backup)
        #expect(try String(contentsOf: backup, encoding: .utf8) == content)
    }

    @Test("propagates missing hosts-file read errors")
    func reportsMissingHostsFile() async {
        let missingFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
        let service = HostsFileService(hostsPath: missingFile)

        do {
            _ = try await service.readHosts()
            Issue.record("Expected a missing-file read error")
        } catch {
            #expect((error as NSError).code == NSFileReadNoSuchFileError)
        }
    }

    @Test("removes the temporary hosts file when the privileged install fails or is cancelled (#256)")
    func removesTemporaryFileWhenInstallFails() async throws {
        let service = HostsFileService(hostsPath: "/etc/hosts")
        let content = "127.0.0.1 app.test\n"
        var capturedPath: String?
        struct InstallCancelled: Error {}

        do {
            try await service.withTemporaryHostsFile(content: content) { tempURL in
                capturedPath = tempURL.path
                // The temporary copy must exist while the install runs.
                #expect(FileManager.default.fileExists(atPath: tempURL.path))
                #expect(try String(contentsOf: tempURL, encoding: .utf8) == content)
                throw InstallCancelled()
            }
            Issue.record("Expected the install error to propagate")
        } catch is InstallCancelled {
            // expected: the install error must surface to the caller
        }

        let path = try #require(capturedPath)
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test("removes the temporary hosts file after a successful install (#256)")
    func removesTemporaryFileAfterSuccessfulInstall() async throws {
        let service = HostsFileService(hostsPath: "/etc/hosts")
        var capturedPath: String?

        try await service.withTemporaryHostsFile(content: "127.0.0.1 app.test\n") { tempURL in
            capturedPath = tempURL.path
            #expect(FileManager.default.fileExists(atPath: tempURL.path))
        }

        let path = try #require(capturedPath)
        #expect(!FileManager.default.fileExists(atPath: path))
    }
}
