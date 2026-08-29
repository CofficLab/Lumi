import Testing
import KernelCore
import ProviderActivityBar
import ProviderChatSection
@testable import BrewManagerPlugin

@MainActor
struct PluginBrewManagerTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = BrewManagerSuperPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.brew-manager")
        #expect(plugin.metadata.name == "Package Management")
        #expect(plugin.order == 260)
        #expect(plugin.metadata.policy == .disabledByDefault)
    }

    @Test
    func v2IdentifiersRemainStable() {
        #expect(BrewManagerSuperPlugin().id.hasSuffix("brew-manager"))
    }

    @Test
    func activatingPluginHidesChatSectionAndDeactivatingRestoresIt() throws {
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)

        try BrewManagerSuperPlugin().onBoot(kernel: kernel)

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
