import Testing
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
@testable import BrewManagerPlugin

@MainActor
struct PluginBrewManagerTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = BrewManagerPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.brew-manager")
        #expect(plugin.metadata.name == pluginLocalization.string("Package Management"))
        #expect(plugin.order == 260)
        #expect(plugin.metadata.policy == .disabledByDefault)
    }

    @Test
    func v2IdentifiersRemainStable() {
        #expect(BrewManagerPlugin().id.hasSuffix("brew-manager"))
    }

    @Test
    func decodesHomebrewFormulaAndCaskInstalledValues() throws {
        let data = Data(
            #"""
            {
              "formulae": [{
                "name": "node",
                "versions": {"stable": "26.7.0"},
                "installed": [{"version": "26.4.0", "installed_on_request": true}]
              }],
              "casks": [{
                "name": ["Applite"],
                "token": "applite",
                "version": "1.2.5",
                "installed": "1.2.5"
              }]
            }
            """#.utf8
        )

        let info = try JSONDecoder().decode(BrewInfo.self, from: data)

        #expect(info.formulae.first?.installed?.first?.version == "26.4.0")
        #expect(info.casks.first?.name == "Applite")
        #expect(info.casks.first?.installed == nil)
        #expect(info.casks.first?.version == "1.2.5")
    }

    @Test
    func decodesFormulaNameStringAndCaskNameArray() throws {
        let data = Data(
            #"""
            {
              "formulae": [{"name": "node"}],
              "casks": [{"name": ["Google Chrome"], "token": "google-chrome"}]
            }
            """#.utf8
        )

        let info = try JSONDecoder().decode(BrewInfo.self, from: data)

        #expect(info.formulae.first?.name == "node")
        #expect(info.casks.first?.name == "Google Chrome")
    }

    @Test
    func activatingPluginHidesChatSectionAndDeactivatingRestoresIt() throws {
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)

        try BrewManagerPlugin().onBoot(kernel: kernel)

        #expect(activity.activeItemID == "com.coffic.lumi.plugin.brew-manager.entry")
        #expect(!chat.isVisible)

        activity.activateItem(id: nil)

        #expect(chat.isVisible)
    }

    @Test
    func clearingSearchIgnoresInFlightResults() async throws {
        let package = BrewPackage(
            name: "node",
            desc: "JavaScript runtime",
            homepage: nil,
            version: "1.0.0",
            installedVersion: nil,
            outdated: false,
            isCask: false
        )
        let service = FakeBrewManagerService(searchResults: [package])
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)

        viewModel.searchText = "node"
        viewModel.performSearch()

        try await Task.sleep(nanoseconds: 600_000_000)
        viewModel.searchText = ""
        viewModel.performSearch()
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func editingSearchTextAfterSubmitStopsLoadingWhenStaleResultReturns() async throws {
        let package = BrewPackage(
            name: "node",
            desc: "JavaScript runtime",
            homepage: nil,
            version: "1.0.0",
            installedVersion: nil,
            outdated: false,
            isCask: false
        )
        let service = FakeBrewManagerService(searchResults: [package])
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)

        viewModel.searchText = "node"
        viewModel.performSearch()

        try await Task.sleep(nanoseconds: 550_000_000)
        viewModel.searchText = "python"
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func brewErrorDescriptionsCarryCommandDetail() {
        #expect(BrewError.commandFailed("  Error: permission denied\n").errorDescription == "Error: permission denied")
        #expect(BrewError.commandFailed("   \n").errorDescription == "The brew command failed.")
        #expect(BrewError.notInstalled.errorDescription?.isEmpty == false)
        #expect(BrewError.notFound.errorDescription?.isEmpty == false)
        #expect(BrewError.parsingError(NSError(domain: "t", code: 1)).errorDescription?.contains("parse") == true)
    }

    @Test
    func installFailureShowsCommandDetailToUser() async throws {
        let package = BrewPackage(
            name: "node",
            desc: "JavaScript runtime",
            homepage: nil,
            version: "1.0.0",
            installedVersion: nil,
            outdated: false,
            isCask: false
        )
        let viewModel = BrewManagerViewModel(service: FailingBrewManagerService(), autoCheckEnvironment: false)

        await viewModel.install(package: package)

        // 旧实现里 BrewError 没有 errorDescription，这里只会得到
        // "The operation couldn't be completed. (BrewManagerPlugin.BrewError error 1.)"。
        #expect(viewModel.errorMessage?.contains("permission denied") == true)
    }

    @Test
    func installSuccessReconcilesSearchResults() async throws {
        let service = StatefulBrewManagerService(installed: [])
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)

        viewModel.searchText = "node"
        viewModel.performSearch()
        try await Task.sleep(nanoseconds: 700_000_000)

        guard let result = viewModel.searchResults.first else {
            Issue.record("搜索没有返回结果")
            return
        }
        #expect(result.installedVersion == nil)

        await viewModel.install(package: result)

        // 旧实现只刷新 installedPackages，Search 行仍是未安装状态。
        #expect(viewModel.searchResults.first?.installedVersion == "26.4.0")
        #expect(viewModel.searchResults.first?.isInstalled == true)
    }

    @Test
    func uninstallSuccessReconcilesSearchResults() async throws {
        let service = StatefulBrewManagerService(installed: ["node"])
        let viewModel = BrewManagerViewModel(service: service, autoCheckEnvironment: false)

        viewModel.searchText = "node"
        viewModel.performSearch()
        try await Task.sleep(nanoseconds: 700_000_000)

        guard let result = viewModel.searchResults.first else {
            Issue.record("搜索没有返回结果")
            return
        }
        #expect(result.installedVersion == "26.4.0")

        await viewModel.uninstall(package: result)

        // 旧实现会让 Search 行继续显示已安装并隐藏 Install 按钮。
        #expect(viewModel.searchResults.first?.installedVersion == nil)
        #expect(viewModel.searchResults.first?.isInstalled == false)
    }
}

private actor StatefulBrewManagerService: BrewManagerServicing {
    private var installed: Set<String>

    init(installed: Set<String>) {
        self.installed = installed
    }

    private func makePackage(name: String, installedVersion: String?) -> BrewPackage {
        BrewPackage(
            name: name,
            desc: "JavaScript runtime",
            homepage: nil,
            version: "26.4.0",
            installedVersion: installedVersion,
            outdated: false,
            isCask: false
        )
    }

    func checkInstalled() async -> Bool { true }

    func listInstalled() async throws -> [BrewPackage] {
        installed.contains("node") ? [makePackage(name: "node", installedVersion: "26.4.0")] : []
    }

    func getOutdated() async throws -> [BrewPackage] { [] }

    func search(query: String) async throws -> [BrewPackage] {
        [makePackage(name: "node", installedVersion: installed.contains("node") ? "26.4.0" : nil)]
    }

    func install(name: String, isCask: Bool) async throws {
        installed.insert(name)
    }

    func uninstall(name: String, isCask: Bool) async throws {
        installed.remove(name)
    }

    func upgrade(name: String, isCask: Bool) async throws {}
    func upgradeAll() async throws {}
}

private actor FailingBrewManagerService: BrewManagerServicing {
    func checkInstalled() async -> Bool { true }
    func listInstalled() async throws -> [BrewPackage] { [] }
    func getOutdated() async throws -> [BrewPackage] { [] }
    func search(query: String) async throws -> [BrewPackage] { [] }
    func install(name: String, isCask: Bool) async throws {
        throw BrewError.commandFailed("Error: permission denied")
    }
    func uninstall(name: String, isCask: Bool) async throws {}
    func upgrade(name: String, isCask: Bool) async throws {}
    func upgradeAll() async throws {}
}

private actor FakeBrewManagerService: BrewManagerServicing {
    let searchResults: [BrewPackage]

    init(searchResults: [BrewPackage]) {
        self.searchResults = searchResults
    }

    func checkInstalled() async -> Bool {
        true
    }

    func listInstalled() async throws -> [BrewPackage] {
        []
    }

    func getOutdated() async throws -> [BrewPackage] {
        []
    }

    func search(query: String) async throws -> [BrewPackage] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return searchResults
    }

    func install(name: String, isCask: Bool) async throws {}

    func uninstall(name: String, isCask: Bool) async throws {}

    func upgrade(name: String, isCask: Bool) async throws {}
}
