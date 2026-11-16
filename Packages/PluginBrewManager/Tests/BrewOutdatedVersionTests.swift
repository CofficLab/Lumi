import Testing
import Foundation
@testable import BrewManagerPlugin

/// 回归 #847：`getOutdated` 把 `brew outdated --json=v2` 当成 `brew info` 的
/// `BrewInfo` 解码。outdated 条目根本没有 `versions`/`version` 字段，目标版本在
/// `current_version`、已装版本在 `installed_versions`（数组），于是 Updates 页
/// 每个包的目标版本都退化成 "unknown"。这里用真实 outdated schema 锁定修复。
struct BrewOutdatedVersionTests {

    // MARK: - 目标版本来自 current_version（核心 bug）

    @Test("getOutdated 的 Formula 目标版本必须是 current_version，不得为 unknown")
    func outdatedFormulaTargetVersionIsCurrentVersion() async throws {
        let service = makeService(stdout: #"{"formulae":[{"name":"ada-url","installed_versions":["3.4.4"],"current_version":"4.0.0_1","pinned":false,"pinned_version":null}],"casks":[]}"#)
        let packages = try await service.getOutdated()
        let formula = try #require(packages.first)
        #expect(formula.version == "4.0.0_1")
        #expect(formula.version != "unknown")
        #expect(formula.outdated == true)
        #expect(formula.isCask == false)
    }

    @Test("getOutdated 的 Cask 目标版本必须是 current_version，不得为 unknown")
    func outdatedCaskTargetVersionIsCurrentVersion() async throws {
        let service = makeService(stdout: #"{"formulae":[],"casks":[{"name":"android-commandlinetools","installed_versions":["14742923"],"current_version":"15859902","pinned":false,"pinned_version":null}]}"#)
        let packages = try await service.getOutdated()
        let cask = try #require(packages.first)
        #expect(cask.version == "15859902")
        #expect(cask.version != "unknown")
        #expect(cask.isCask == true)
    }

    // MARK: - 已装版本来自 installed_versions

    @Test("getOutdated 的 Formula 已装版本取 installed_versions 首个（多 keg）")
    func outdatedFormulaInstalledVersionUsesFirstKeg() async throws {
        let service = makeService(stdout: #"{"formulae":[{"name":"node","installed_versions":["26.4.0","26.5.0"],"current_version":"26.7.0","pinned":false,"pinned_version":null}],"casks":[]}"#)
        let packages = try await service.getOutdated()
        let formula = try #require(packages.first)
        #expect(formula.installedVersion == "26.4.0")
    }

    @Test("getOutdated 的 Cask 已装版本来自 installed_versions，不得丢失")
    func outdatedCaskInstalledVersionIsReal() async throws {
        let service = makeService(stdout: #"{"formulae":[],"casks":[{"name":"applite","installed_versions":["1.2.5"],"current_version":"1.3.0","pinned":false,"pinned_version":null}]}"#)
        let packages = try await service.getOutdated()
        let cask = try #require(packages.first)
        #expect(cask.installedVersion == "1.2.5")
    }

    // MARK: - 身份与模型 schema

    @Test("getOutdated 的 Cask name 即 token，作为包身份")
    func outdatedCaskNameIsToken() async throws {
        let service = makeService(stdout: #"{"formulae":[],"casks":[{"name":"google-chrome","installed_versions":["120.0"],"current_version":"121.0","pinned":false,"pinned_version":null}]}"#)
        let packages = try await service.getOutdated()
        let cask = try #require(packages.first)
        #expect(cask.name == "google-chrome")
        #expect(cask.id == "google-chrome")
    }

    @Test("BrewOutdated 模型按真实 schema 解码 formula 与 cask")
    func outdatedModelDecodesRealSchema() throws {
        let json = """
        {"formulae":[
          {"name":"ada-url","installed_versions":["3.4.4"],"current_version":"4.0.0_1","pinned":false,"pinned_version":null},
          {"name":"anomalyco/tap/opencode","installed_versions":["1.0","1.1"],"current_version":"2.0","pinned":true,"pinned_version":"1.0"}
        ],"casks":[
          {"name":"android-commandlinetools","installed_versions":["14742923"],"current_version":"15859902","pinned":false,"pinned_version":null}
        ]}
        """
        let outdated = try JSONDecoder().decode(BrewOutdated.self, from: Data(json.utf8))
        #expect(outdated.formulae.count == 2)
        #expect(outdated.casks.count == 1)

        let core = try #require(outdated.formulae.first)
        #expect(core.name == "ada-url")
        #expect(core.current_version == "4.0.0_1")
        #expect(core.installed_versions == ["3.4.4"])
        #expect(core.pinned == false)
        #expect(core.pinned_version == nil)

        let tap = outdated.formulae[1]
        #expect(tap.name == "anomalyco/tap/opencode")
        #expect(tap.installed_versions == ["1.0", "1.1"])
        #expect(tap.pinned == true)
        #expect(tap.pinned_version == "1.0")

        let cask = try #require(outdated.casks.first)
        #expect(cask.name == "android-commandlinetools")
        #expect(cask.current_version == "15859902")
        #expect(cask.installed_versions == ["14742923"])
    }

    @Test("getOutdated 空列表返回空数组，不崩溃")
    func outdatedEmptyListsReturnNoPackages() async throws {
        let service = makeService(stdout: #"{"formulae":[],"casks":[]}"#)
        let packages = try await service.getOutdated()
        #expect(packages.isEmpty)
    }

    // MARK: - Helpers

    private func makeService(stdout: String) -> BrewService {
        BrewService(brewPath: "/opt/homebrew/bin/brew", commandRunner: { _, _, _ in
            BrewCommandResult(exitCode: 0, stdout: stdout, stderr: "")
        })
    }
}