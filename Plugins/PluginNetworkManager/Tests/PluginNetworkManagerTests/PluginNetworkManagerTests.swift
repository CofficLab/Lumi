import Testing
@testable import PluginNetworkManager

@MainActor
@Test func publicIPRefreshUsesCache() async throws {
    let fetcher = PublicIPFetcherStub(values: ["203.0.113.10"])
    let viewModel = NetworkManagerViewModel(autoStartMonitoring: false) {
        await fetcher.fetch()
    }

    await viewModel.refreshPublicIPIfNeeded()
    await viewModel.refreshPublicIPIfNeeded()

    #expect(await fetcher.count == 1)
    #expect(viewModel.networkState.publicIP == "203.0.113.10")
}

@MainActor
@Test func publicIPRefreshCanBeForced() async throws {
    let fetcher = PublicIPFetcherStub(values: ["203.0.113.1", "203.0.113.2"])
    let viewModel = NetworkManagerViewModel(autoStartMonitoring: false) {
        await fetcher.fetch()
    }

    await viewModel.refreshPublicIPIfNeeded()
    await viewModel.refreshPublicIPIfNeeded(force: true)

    #expect(await fetcher.count == 2)
    #expect(viewModel.networkState.publicIP == "203.0.113.2")
}

private actor PublicIPFetcherStub {
    private(set) var count = 0
    private let values: [String]

    init(values: [String]) {
        self.values = values
    }

    func fetch() -> String? {
        count += 1
        return values[min(count - 1, values.count - 1)]
    }
}
