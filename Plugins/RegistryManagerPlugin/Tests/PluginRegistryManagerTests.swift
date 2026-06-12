import Foundation
import Testing
@testable import RegistryManagerPlugin

@MainActor
@Test
func staleRefreshDoesNotOverwriteNewerRegistryResult() async throws {
    let service = FakeRegistryManagerService(
        getResults: [
            .npm: [
                (delay: 200_000_000, result: "https://stale.example/"),
                (delay: 20_000_000, result: "https://fresh.example/"),
            ]
        ]
    )
    let viewModel = RegistryManagerViewModel(service: service, autoRefresh: false)

    let firstRefresh = Task {
        await viewModel.refresh(.npm)
    }
    try await Task.sleep(nanoseconds: 50_000_000)
    await viewModel.refresh(.npm)
    await firstRefresh.value

    #expect(viewModel.registries[.npm] == "https://fresh.example/")
    #expect(viewModel.isLoading[.npm] == false)
}

@MainActor
@Test
func staleSetDoesNotOverwriteNewerRegistryChoice() async throws {
    let staleSource = RegistrySource(name: "Stale", url: "https://stale.example/", type: .npm)
    let freshSource = RegistrySource(name: "Fresh", url: "https://fresh.example/", type: .npm)
    let service = FakeRegistryManagerService(setDelays: [
        staleSource.url: 200_000_000,
        freshSource.url: 20_000_000,
    ])
    let viewModel = RegistryManagerViewModel(service: service, autoRefresh: false)

    let firstSet = Task {
        await viewModel.setRegistry(.npm, source: staleSource)
    }
    try await Task.sleep(nanoseconds: 50_000_000)
    await viewModel.setRegistry(.npm, source: freshSource)
    await firstSet.value

    #expect(viewModel.registries[.npm] == freshSource.url)
    #expect(viewModel.isLoading[.npm] == false)
    #expect(viewModel.toastMessage.contains("Fresh"))
    let appliedURLs = await service.appliedURLs
    #expect(appliedURLs == [staleSource.url, freshSource.url])
}

private actor FakeRegistryManagerService: RegistryManagerServicing {
    private var getResults: [RegistryType: [(delay: UInt64, result: String)]]
    private let setDelays: [String: UInt64]
    private var appliedSetURLs: [String] = []

    var appliedURLs: [String] {
        appliedSetURLs
    }

    init(
        getResults: [RegistryType: [(delay: UInt64, result: String)]] = [:],
        setDelays: [String: UInt64] = [:]
    ) {
        self.getResults = getResults
        self.setDelays = setDelays
    }

    func getCurrentRegistry(for type: RegistryType) async throws -> String {
        let next = nextGetResult(for: type)
        try? await Task.sleep(nanoseconds: next.delay)
        return next.result
    }

    func setRegistry(for type: RegistryType, url: String) async throws {
        if let delay = setDelays[url] {
            try? await Task.sleep(nanoseconds: delay)
        }
        appliedSetURLs.append(url)
    }

    private func nextGetResult(for type: RegistryType) -> (delay: UInt64, result: String) {
        var queue = getResults[type] ?? []
        guard !queue.isEmpty else {
            return (0, "Default")
        }
        let next = queue.removeFirst()
        getResults[type] = queue
        return next
    }
}
