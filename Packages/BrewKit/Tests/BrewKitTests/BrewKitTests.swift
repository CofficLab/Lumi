import Foundation
import Testing
@testable import BrewKit

@Suite("BrewKit Models Tests")
struct BrewKitModelsTests {

    @Test("BrewPackage initialization")
    func brewPackageInit() {
        let package = BrewPackage(
            name: "git",
            desc: "Distributed version control system",
            homepage: "https://git-scm.com",
            version: "2.43.0",
            installedVersion: "2.42.0",
            outdated: true,
            isCask: false
        )

        #expect(package.id == "git")
        #expect(package.isInstalled == true)
        #expect(package.outdated == true)
        #expect(package.isCask == false)
    }

    @Test("BrewPackage not installed")
    func brewPackageNotInstalled() {
        let package = BrewPackage(
            name: "node",
            desc: nil,
            homepage: nil,
            version: "21.0.0",
            installedVersion: nil,
            outdated: false,
            isCask: false
        )

        #expect(package.isInstalled == false)
    }

    @Test("BrewVersions decoding")
    func brewVersionsDecoding() {
        let json = """
        {"stable": "1.0.0"}
        """
        let data = json.data(using: .utf8)!
        let versions = try! JSONDecoder().decode(BrewVersions.self, from: data)

        #expect(versions.stable == "1.0.0")
    }
}

@Suite("BrewKit Service Tests")
struct BrewKitServiceTests {

    @Test("BrewService shared instance")
    func brewServiceShared() async {
        let service = BrewService.shared
        let installed = await service.checkInstalled()
        #expect(installed == true || installed == false)
    }

    @Test("BrewError equality")
    func brewErrorEquality() {
        #expect(BrewError.notInstalled == BrewError.notInstalled)
        #expect(BrewError.commandFailed("test") == BrewError.commandFailed("test"))
        #expect(BrewError.notFound == BrewError.notFound)
        #expect(BrewError.notInstalled != BrewError.notFound)
    }

    @Test("Brew search includes formulae and casks")
    func brewSearchIncludesFormulaeAndCasks() async throws {
        let log = BrewCommandLog()
        let service = BrewService(brewPath: "/opt/homebrew/bin/brew") { _, arguments, _ in
            log.record(arguments)
            switch arguments {
            case ["search", "--formula", "rip"]:
                return BrewCommandResult(exitCode: 0, stdout: "ripgrep\n", stderr: "")
            case ["search", "--cask", "rip"]:
                return BrewCommandResult(exitCode: 0, stdout: "ripcord\n", stderr: "")
            case ["info", "--json=v2", "ripgrep"]:
                return BrewCommandResult(exitCode: 0, stdout: Self.formulaInfoJSON, stderr: "")
            case ["info", "--json=v2", "--cask", "ripcord"]:
                return BrewCommandResult(exitCode: 0, stdout: Self.caskInfoJSON, stderr: "")
            default:
                return BrewCommandResult(exitCode: 1, stdout: "", stderr: "unexpected arguments: \(arguments)")
            }
        }

        let results = try await service.search(query: "rip")

        #expect(results.count == 2)
        #expect(results[0].name == "ripgrep")
        #expect(results[0].isCask == false)
        #expect(results[1].name == "ripcord")
        #expect(results[1].isCask == true)
        #expect(log.commands.contains(["search", "--formula", "rip"]))
        #expect(log.commands.contains(["search", "--cask", "rip"]))
    }

    private static let formulaInfoJSON = """
    {
      "formulae": [
        {
          "name": "ripgrep",
          "full_name": "ripgrep",
          "desc": "Search tool",
          "homepage": "https://github.com/BurntSushi/ripgrep",
          "versions": { "stable": "14.1.1" },
          "installed": [],
          "outdated": false
        }
      ],
      "casks": []
    }
    """

    private static let caskInfoJSON = """
    {
      "formulae": [],
      "casks": [
        {
          "name": "Ripcord",
          "token": "ripcord",
          "desc": "Desktop chat client",
          "homepage": "https://example.com",
          "version": "0.4.29"
        }
      ]
    }
    """
}

private final class BrewCommandLog: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedCommands: [[String]] = []

    var commands: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCommands
    }

    func record(_ arguments: [String]) {
        lock.lock()
        recordedCommands.append(arguments)
        lock.unlock()
    }
}
