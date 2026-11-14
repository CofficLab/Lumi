import Testing
import Foundation
@testable import BrewManagerPlugin

/// 错误视图「重试」必须重跑最近失败的操作，而不是仅清除错误（#330）。
@MainActor
struct BrewManagerRetryTests {

    // MARK: - Helpers

    private func waitUntil(timeout: TimeInterval = 5, _ condition: @MainActor () async -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func makePackage() -> BrewPackage {
        BrewPackage(
            name: "node",
            desc: "JavaScript runtime",
            homepage: nil,
            version: "1.0.0",
            installedVersion: nil,
            outdated: false,
            isCask: false
        )
    }

    // MARK: - Environment

    @Test
    func retryRechecksEnvironmentWhenBrewMissing() async {
        let service = RetryBrewService(brewAvailable: false)
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)

        viewModel.checkEnvironment()
        await waitUntil { viewModel.errorMessage != nil }
        #expect(viewModel.isBrewInstalled == false)
        #expect(await service.checkInstalledCalls == 1)

        viewModel.retry()
        await waitUntil { await service.checkInstalledCalls >= 2 && viewModel.errorMessage != nil }

        // 重试必须再次检测环境，而不是只把错误清掉。
        #expect(await service.checkInstalledCalls == 2)
        #expect(viewModel.isBrewInstalled == false)
        // 仍然失败时错误必须保留，不能伪装成正常空列表。
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func retryEnvironmentSucceedsAfterBrewInstalled() async {
        let service = RetryBrewService(brewAvailable: false)
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)

        viewModel.checkEnvironment()
        await waitUntil { viewModel.errorMessage != nil }
        #expect(viewModel.isBrewInstalled == false)

        await service.setBrewAvailable(true)
        viewModel.retry()
        await waitUntil { viewModel.isBrewInstalled && viewModel.errorMessage == nil }

        #expect(viewModel.isBrewInstalled == true)
        #expect(viewModel.errorMessage == nil)
        #expect(await service.checkInstalledCalls == 2)
        // 环境恢复后应自动刷新数据。
        #expect(await service.listInstalledCalls >= 1)
    }

    // MARK: - Refresh

    @Test
    func retryRerunsFailedRefresh() async {
        let service = RetryBrewService(brewAvailable: true, refreshFailures: 1)
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)

        await viewModel.refresh()
        #expect(viewModel.errorMessage != nil)
        #expect(await service.listInstalledCalls == 1)

        viewModel.retry()
        await waitUntil { viewModel.errorMessage == nil && !viewModel.installedPackages.isEmpty }

        #expect(await service.listInstalledCalls == 2)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.installedPackages.count == 1)
    }

    @Test
    func retryKeepsErrorWhenRefreshStillFails() async {
        let service = RetryBrewService(brewAvailable: true, refreshFailures: 2)
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)

        await viewModel.refresh()
        #expect(viewModel.errorMessage != nil)
        #expect(await service.listInstalledCalls == 1)

        viewModel.retry()
        await waitUntil { await service.listInstalledCalls >= 2 && viewModel.errorMessage != nil }

        #expect(await service.listInstalledCalls == 2)
        // 重试仍失败时错误必须显式保留。
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.installedPackages.isEmpty)
    }

    // MARK: - Install

    @Test
    func retryRerunsFailedInstallWithSamePackage() async {
        let service = RetryBrewService(installFailures: 1)
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)
        let package = makePackage()

        await viewModel.install(package: package)
        #expect(viewModel.errorMessage != nil)
        #expect(await service.installCalls == 1)
        #expect(await service.installedNames == ["node"])

        viewModel.retry()
        await waitUntil { await service.installCalls >= 2 && viewModel.errorMessage == nil }

        #expect(await service.installCalls == 2)
        // 重试必须针对同一个包再次安装。
        #expect(await service.installedNames == ["node", "node"])
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Search

    @Test
    func retryRerunsFailedSearch() async {
        let service = RetryBrewService(searchFailures: 1)
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)

        viewModel.searchText = "node"
        viewModel.performSearch()
        await waitUntil { viewModel.errorMessage != nil }
        #expect(await service.searchCalls == 1)

        viewModel.retry()
        await waitUntil { viewModel.errorMessage == nil && !viewModel.searchResults.isEmpty }

        #expect(await service.searchCalls == 2)
        #expect(viewModel.searchResults.count == 1)
        #expect(viewModel.errorMessage == nil)
    }
}

// MARK: - Stub

/// 可配置失败次数并记录调用的测试替身。
private actor RetryBrewService: BrewManagerServicing {
    private var brewAvailable: Bool
    private var refreshFailures: Int
    private var installFailures: Int
    private var searchFailures: Int

    private(set) var checkInstalledCalls = 0
    private(set) var listInstalledCalls = 0
    private(set) var installCalls = 0
    private(set) var searchCalls = 0
    private(set) var installedNames: [String] = []

    init(brewAvailable: Bool = true, refreshFailures: Int = 0, installFailures: Int = 0, searchFailures: Int = 0) {
        self.brewAvailable = brewAvailable
        self.refreshFailures = refreshFailures
        self.installFailures = installFailures
        self.searchFailures = searchFailures
    }

    func setBrewAvailable(_ value: Bool) {
        brewAvailable = value
    }

    private var package: BrewPackage {
        BrewPackage(
            name: "node",
            desc: "JavaScript runtime",
            homepage: nil,
            version: "26.4.0",
            installedVersion: "26.4.0",
            outdated: false,
            isCask: false
        )
    }

    func checkInstalled() async -> Bool {
        checkInstalledCalls += 1
        return brewAvailable
    }

    func listInstalled() async throws -> [BrewPackage] {
        listInstalledCalls += 1
        if refreshFailures > 0 {
            refreshFailures -= 1
            throw BrewError.commandFailed("Error: refresh boom")
        }
        return [package]
    }

    func getOutdated() async throws -> [BrewPackage] { [] }

    func search(query: String) async throws -> [BrewPackage] {
        searchCalls += 1
        if searchFailures > 0 {
            searchFailures -= 1
            throw BrewError.commandFailed("Error: search boom")
        }
        return [package]
    }

    func install(name: String, isCask: Bool) async throws {
        installCalls += 1
        installedNames.append(name)
        if installFailures > 0 {
            installFailures -= 1
            throw BrewError.commandFailed("Error: install boom")
        }
    }

    func uninstall(name: String, isCask: Bool) async throws {}
    func upgrade(name: String, isCask: Bool) async throws {}
}