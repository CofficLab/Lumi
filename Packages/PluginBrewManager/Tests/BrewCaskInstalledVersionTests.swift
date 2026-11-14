import Testing
import Foundation
@testable import BrewManagerPlugin

/// Regression for #212: Homebrew casks expose `installed` as a version string
/// (formulae use an array). The decoder ignored the string and the service
/// hardcoded installedVersion/outdated, so an installed cask showed as not
/// installed and the Installed page passed off the latest version as installed.
struct BrewCaskInstalledVersionTests {

    // MARK: - Model decoding

    @Test("cask 的字符串 installed 必须解码为安装版本，不得丢失")
    func decodesCaskInstalledStringIntoVersion() throws {
        let info = try decode(#"{"formulae":[],"casks":[{"name":["Applite"],"token":"applite","version":"1.3.0","installed":"1.2.5"}]}"#)
        #expect(info.casks.first?.installed?.first?.version == "1.2.5")
        #expect(info.casks.first?.installed?.first?.installed_on_request == nil)
    }

    @Test("cask 的 installed 为 null 时解码为未安装")
    func decodesCaskInstalledNullAsNotInstalled() throws {
        let info = try decode(#"{"formulae":[],"casks":[{"name":["Applite"],"token":"applite","version":"1.3.0","installed":null}]}"#)
        #expect(info.casks.first?.installed == nil)
    }

    @Test("formula 的数组 installed 解码保持不变（无回归）")
    func decodesFormulaInstalledArrayUnchanged() throws {
        let info = try decode(#"{"formulae":[{"name":"node","versions":{"stable":"26.7.0"},"installed":[{"version":"26.4.0","installed_on_request":true}]}],"casks":[]}"#)
        #expect(info.formulae.first?.installed?.first?.version == "26.4.0")
        #expect(info.formulae.first?.installed?.first?.installed_on_request == true)
    }

    // MARK: - Service chain (injected command runner)

    @Test("getInfo(cask) 必须保留真实安装版本与 outdated 状态")
    func getInfoCaskPreservesInstalledVersionAndOutdated() async throws {
        let service = makeService(stdout: #"{"formulae":[],"casks":[{"name":["Applite"],"token":"applite","version":"1.3.0","installed":"1.2.5","outdated":true}]}"#)
        let packages = try await service.getInfo(names: ["applite"], isCask: true)
        let cask = try #require(packages.first)
        #expect(cask.installedVersion == "1.2.5")
        #expect(cask.version == "1.3.0")
        #expect(cask.outdated == true)
        #expect(cask.isInstalled == true)
    }

    @Test("getInfo(cask) 未安装时安装版本为 nil")
    func getInfoCaskNotInstalledShowsNil() async throws {
        let service = makeService(stdout: #"{"formulae":[],"casks":[{"name":["Applite"],"token":"applite","version":"1.3.0","installed":null,"outdated":false}]}"#)
        let packages = try await service.getInfo(names: ["applite"], isCask: true)
        let cask = try #require(packages.first)
        #expect(cask.installedVersion == nil)
        #expect(cask.isInstalled == false)
        #expect(cask.outdated == false)
    }

    @Test("listInstalled 的 cask 不得把最新版本当作安装版本")
    func listInstalledCaskUsesRealInstalledVersionNotLatest() async throws {
        let service = makeService(stdout: #"{"formulae":[],"casks":[{"name":["Applite"],"token":"applite","version":"1.3.0","installed":"1.2.5","outdated":true}]}"#)
        let packages = try await service.listInstalled()
        let cask = try #require(packages.first)
        #expect(cask.installedVersion == "1.2.5")
        #expect(cask.installedVersion != cask.version)
        #expect(cask.outdated == true)
    }

    @Test("getOutdated 的 cask 保留真实安装版本")
    func getOutdatedCaskPreservesInstalledVersion() async throws {
        let service = makeService(stdout: #"{"formulae":[],"casks":[{"name":["Applite"],"token":"applite","version":"1.3.0","installed":"1.2.5"}]}"#)
        let packages = try await service.getOutdated()
        let cask = try #require(packages.first)
        #expect(cask.installedVersion == "1.2.5")
        #expect(cask.outdated == true)
    }

    @Test("getInfo(formula) 保留 outdated 标记")
    func getInfoFormulaPreservesOutdatedFlag() async throws {
        let service = makeService(stdout: #"{"formulae":[{"name":"node","versions":{"stable":"26.7.0"},"installed":[{"version":"26.4.0"}],"outdated":true}],"casks":[]}"#)
        let packages = try await service.getInfo(names: ["node"], isCask: false)
        let formula = try #require(packages.first)
        #expect(formula.installedVersion == "26.4.0")
        #expect(formula.outdated == true)
    }

    // MARK: - Helpers

    private func decode(_ json: String) throws -> BrewInfo {
        try JSONDecoder().decode(BrewInfo.self, from: Data(json.utf8))
    }

    private func makeService(stdout: String) -> BrewService {
        BrewService(brewPath: "/opt/homebrew/bin/brew", commandRunner: { _, _, _ in
            BrewCommandResult(exitCode: 0, stdout: stdout, stderr: "")
        })
    }
}
