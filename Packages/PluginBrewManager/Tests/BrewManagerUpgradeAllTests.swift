import Testing
import Foundation
@testable import BrewManagerPlugin

/// 连点 Update All 只能跑一轮批量升级，结束后允许再次触发（#409）。
@MainActor
struct BrewManagerUpgradeAllTests {

    // MARK: - Helpers

    private func makeViewModel(service: UpgradeAllStubService) -> BrewManagerViewModel {
        BrewManagerViewModel(service: service, autoCheckEnvironment: false)
    }

    // MARK: - Single flight

    @Test
    func concurrentUpgradeAllRunsSingleFlight() async {
        let service = UpgradeAllStubService()
        let viewModel = makeViewModel(service: service)
        await viewModel.refresh()
        #expect(viewModel.outdatedPackages.count == 2)

        async let first: Void = viewModel.upgradeAll()
        async let second: Void = viewModel.upgradeAll()
        _ = await (first, second)

        // 连点两次只应跑一轮：每个包恰好升级一次，不能并发重复写。
        #expect(await service.upgradeCalls == 2)
        #expect(await service.upgradedNames.sorted() == ["a", "b"])
        // 唯一一轮结束后 loading 必须落下。
        #expect(viewModel.isLoading == false)
    }

    @Test
    func upgradeAllUpgradesEveryOutdatedPackage() async {
        let service = UpgradeAllStubService()
        let viewModel = makeViewModel(service: service)
        await viewModel.refresh()

        await viewModel.upgradeAll()

        #expect(await service.upgradeCalls == 2)
        #expect(await service.upgradedNames.sorted() == ["a", "b"])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func upgradeAllCanBeRunAgainAfterCompletion() async {
        let service = UpgradeAllStubService()
        let viewModel = makeViewModel(service: service)
        await viewModel.refresh()

        await viewModel.upgradeAll()
        #expect(await service.upgradeCalls == 2)

        await viewModel.upgradeAll()
        // 上一轮结束后进行中标志必须复位，允许再次批量更新。
        #expect(await service.upgradeCalls == 4)
        #expect(viewModel.isLoading == false)
    }
}

// MARK: - Stub

/// 返回两个可更新包并记录每次升级的测试替身。
private actor UpgradeAllStubService: BrewManagerServicing {
    private(set) var upgradeCalls = 0
    private(set) var upgradedNames: [String] = []

    private func package(_ name: String) -> BrewPackage {
        BrewPackage(
            name: name,
            desc: "\(name) package",
            homepage: nil,
            version: "2.0.0",
            installedVersion: "1.0.0",
            outdated: true,
            isCask: false
        )
    }

    func checkInstalled() async -> Bool { true }
    func listInstalled() async throws -> [BrewPackage] { [package("a"), package("b")] }
    func getOutdated() async throws -> [BrewPackage] { [package("a"), package("b")] }
    func search(query: String) async throws -> [BrewPackage] { [] }
    func install(name: String, isCask: Bool) async throws {}
    func uninstall(name: String, isCask: Bool) async throws {}

    func upgrade(name: String, isCask: Bool) async throws {
        upgradeCalls += 1
        upgradedNames.append(name)
        // 让出执行权，制造连点并发窗口。
        try? await Task.sleep(nanoseconds: 30_000_000)
    }
}