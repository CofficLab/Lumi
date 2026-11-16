import Testing
import Foundation
@testable import BrewManagerPlugin

/// 卸载必须先确认，单击不得立即执行破坏性的 brew uninstall（#656）。
///
/// 行内 Uninstall 按钮只调用 `requestUninstall` 登记待确认的包；只有确认对话框
/// 的「卸载」按钮调用 `confirmUninstall` 才真正执行。内置手册明确要求确认并警告
/// 可能影响依赖包。
@MainActor
struct BrewManagerUninstallConfirmationTests {

    private func makePackage(name: String = "node") -> BrewPackage {
        BrewPackage(
            name: name,
            desc: "JavaScript runtime",
            homepage: nil,
            version: "1.0.0",
            installedVersion: "1.0.0",
            outdated: false,
            isCask: false
        )
    }

    @Test("单击 Uninstall 只登记待确认包，不执行卸载（回归 #656）")
    func requestUninstallDoesNotExecuteUninstall() async {
        let service = ConfirmationBrewService()
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)
        let package = makePackage()

        viewModel.requestUninstall(package: package)
        // 让出主线程，确保即使 requestUninstall 误派发了异步卸载也会被计数。
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.packagePendingUninstall == package)
        #expect(await service.uninstallCalls == 0)
    }

    @Test("确认后才执行一次卸载并清空待确认包（回归 #656）")
    func confirmUninstallExecutesOnceAndClearsPending() async {
        let service = ConfirmationBrewService()
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)
        let package = makePackage()

        viewModel.requestUninstall(package: package)
        await viewModel.confirmUninstall(package: package)

        #expect(await service.uninstallCalls == 1)
        #expect(await service.uninstalledNames == ["node"])
        #expect(viewModel.packagePendingUninstall == nil)
    }

    @Test("取消确认不执行卸载并清空待确认包（回归 #656）")
    func cancelUninstallDoesNotExecuteUninstall() async {
        let service = ConfirmationBrewService()
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)
        let package = makePackage()

        viewModel.requestUninstall(package: package)
        viewModel.cancelUninstall()

        #expect(viewModel.packagePendingUninstall == nil)
        #expect(await service.uninstallCalls == 0)
    }

    @Test("连续请求不同包时待确认包替换为最后一个，仍未执行卸载")
    func requestUninstallReplacesPendingPackage() async {
        let service = ConfirmationBrewService()
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)

        viewModel.requestUninstall(package: makePackage(name: "node"))
        viewModel.requestUninstall(package: makePackage(name: "wget"))

        #expect(viewModel.packagePendingUninstall?.name == "wget")
        #expect(await service.uninstallCalls == 0)
    }
}

// MARK: - Stub

/// 记录卸载调用的测试替身；其余操作返回空结果。
private actor ConfirmationBrewService: BrewManagerServicing {
    private(set) var uninstallCalls = 0
    private(set) var uninstalledNames: [String] = []

    func checkInstalled() async -> Bool { true }
    func listInstalled() async throws -> [BrewPackage] { [] }
    func getOutdated() async throws -> [BrewPackage] { [] }
    func search(query: String) async throws -> [BrewPackage] { [] }
    func install(name: String, isCask: Bool) async throws {}

    func uninstall(name: String, isCask: Bool) async throws {
        uninstallCalls += 1
        uninstalledNames.append(name)
    }

    func upgrade(name: String, isCask: Bool) async throws {}
}