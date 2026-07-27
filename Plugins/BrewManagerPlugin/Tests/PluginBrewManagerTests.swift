import Testing
import LumiKernel
@testable import BrewManagerPlugin

@MainActor
struct PluginBrewManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(BrewManagerPlugin.id == "BrewManager")
        #expect(BrewManagerPlugin.navigationId == "brew_manager")
        #expect(BrewManagerPlugin.displayName.isEmpty == false)
        #expect(BrewManagerPlugin.description.isEmpty == false)
        #expect(BrewManagerPlugin.iconName == "mug.fill")
        #expect(BrewManagerPlugin.category == .developerTool)
        #expect(BrewManagerPlugin.order == 60)
        #expect(BrewManagerPlugin.isConfigurable == true)
        #expect(BrewManagerPlugin.policy == .optOut)
        #expect(BrewManagerPlugin.shared.instanceLabel == BrewManagerPlugin.id)
    }

    @Test
    func viewContainerContributionIsAvailable() {
        let item = BrewManagerPlugin.shared.addViewContainer()
        #expect(item?.id == BrewManagerPlugin.id)
        #expect(item?.title == BrewManagerPlugin.displayName)
        #expect(item?.icon == BrewManagerPlugin.iconName)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginBrewManagerLocalization.bundle.url(forResource: "BrewManager", withExtension: "xcstrings") != nil)
        #expect(PluginBrewManagerLocalization.string("Package Management").isEmpty == false)
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
