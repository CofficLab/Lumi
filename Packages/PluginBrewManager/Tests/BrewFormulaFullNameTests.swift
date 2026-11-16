import Testing
import Foundation
@testable import BrewManagerPlugin

/// 回归 #655：构造 Formula 时只取短 `name`、丢弃 Homebrew 已返回的 `full_name`。
/// Tap 与 Core 同名时（如 pulumi/tap/pulumi 与 core 的 pulumi），用户选中 Tap
/// 结果却退化成 `brew install pulumi` 装到 Core，两条结果的 Identifiable.id 也碰撞。
/// Formula 的身份与后续命令须保留 `full_name ?? name`。
struct BrewFormulaFullNameTests {

    private let tapFormulaJSON = #"{"formulae":[{"name":"pulumi","full_name":"pulumi/tap/pulumi","versions":{"stable":"3.0"},"installed":[]}],"casks":[]}"#

    @Test("getInfo 的 Formula 必须保留 full_name 作为身份")
    func getInfoFormulaKeepsFullName() async throws {
        let service = makeService(stdout: tapFormulaJSON)
        let packages = try await service.getInfo(names: ["pulumi/tap/pulumi"], isCask: false)
        let formula = try #require(packages.first)
        #expect(formula.name == "pulumi/tap/pulumi")
        #expect(formula.id == "pulumi/tap/pulumi")
    }

    @Test("同名 Tap 与 Core Formula 的 id 不得碰撞")
    func getInfoDistinguishesTapAndCoreIds() async throws {
        let json = #"{"formulae":[{"name":"pulumi","full_name":"pulumi","versions":{"stable":"1.0"},"installed":[]},{"name":"pulumi","full_name":"pulumi/tap/pulumi","versions":{"stable":"3.0"},"installed":[]}],"casks":[]}"#
        let service = makeService(stdout: json)
        let packages = try await service.getInfo(names: ["pulumi", "pulumi/tap/pulumi"], isCask: false)
        #expect(packages.count == 2)
        let ids = Set(packages.map(\.id))
        #expect(ids.count == 2)
        #expect(ids.contains("pulumi/tap/pulumi"))
        #expect(ids.contains("pulumi"))
    }

    @Test("listInstalled 的 Formula 保留 full_name")
    func listInstalledFormulaKeepsFullName() async throws {
        let service = makeService(stdout: tapFormulaJSON)
        let packages = try await service.listInstalled()
        let formula = try #require(packages.first)
        #expect(formula.name == "pulumi/tap/pulumi")
    }

    @Test("getOutdated 的 Formula 保留 Tap 全名身份")
    func getOutdatedFormulaKeepsFullName() async throws {
        // outdated 没有 full_name 字段，name 本身已含 tap 前缀（#847 真实 schema）。
        let json = #"{"formulae":[{"name":"pulumi/tap/pulumi","installed_versions":["2.0"],"current_version":"3.0","pinned":false,"pinned_version":null}],"casks":[]}"#
        let service = makeService(stdout: json)
        let packages = try await service.getOutdated()
        let formula = try #require(packages.first)
        #expect(formula.name == "pulumi/tap/pulumi")
        #expect(formula.id == "pulumi/tap/pulumi")
    }

    @Test("没有 full_name 的 Formula 回退到短 name（无回归）")
    func formulaWithoutFullNameFallsBackToName() async throws {
        let json = #"{"formulae":[{"name":"node","versions":{"stable":"26.0"},"installed":[]}],"casks":[]}"#
        let service = makeService(stdout: json)
        let packages = try await service.getInfo(names: ["node"], isCask: false)
        let formula = try #require(packages.first)
        #expect(formula.name == "node")
        #expect(formula.id == "node")
    }

    // MARK: - Helpers

    private func makeService(stdout: String) -> BrewService {
        BrewService(brewPath: "/opt/homebrew/bin/brew", commandRunner: { _, _, _ in
            BrewCommandResult(exitCode: 0, stdout: stdout, stderr: "")
        })
    }
}