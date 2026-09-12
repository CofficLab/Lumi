import Foundation
import ProviderActivityHeatmap
import Testing
@testable import PluginActivityHeatmap

@Suite("Git activity project view model")
@MainActor
struct GitActivityHeatmapProjectViewModelTests {
    @Test("syncs the matching project snapshot and rejects another repository's snapshot")
    func scopesSnapshotsToTheSelectedProject() {
        let provider = MockActivityHeatmapProvider()
        provider.currentSnapshot = snapshot(path: "/tmp/first", count: 2)
        let capability = GitActivityHeatmapProjectCapability(provider: provider)
        let viewModel = GitActivityHeatmapProjectViewModel(projectPath: "/tmp/first/.", capability: capability)
        let observer = GitActivityHeatmapProjectObserver(capability: capability, viewModel: viewModel)

        #expect(viewModel.snapshot?.days.first?.commitCount == 2)
        #expect(viewModel.isLoading == false)

        provider.currentSnapshot = snapshot(path: "/tmp/other", count: 9)
        provider.isLoading = true
        provider.notify(.snapshotChanged)

        #expect(viewModel.snapshot == nil)
        #expect(viewModel.isLoading)

        observer.cancel()
        provider.currentSnapshot = snapshot(path: "/tmp/first", count: 3)
        provider.isLoading = false
        provider.notify(.snapshotChanged)
        #expect(viewModel.snapshot == nil)
    }

    @Test("updates the watched repository only when the project path changes")
    func updatesRepositoryPath() {
        let provider = MockActivityHeatmapProvider()
        let capability = GitActivityHeatmapProjectCapability(provider: provider)
        let viewModel = GitActivityHeatmapProjectViewModel(projectPath: "/tmp/first", capability: capability)

        viewModel.update(projectPath: "/tmp/first")
        #expect(provider.refreshPaths.isEmpty)

        viewModel.update(projectPath: "/tmp/second/.")
        #expect(provider.refreshPaths == ["/tmp/second"])
        #expect(viewModel.snapshot == nil)
        #expect(viewModel.isLoading)
    }

    private func snapshot(path: String, count: Int) -> ActivityHeatmapSnapshot {
        ActivityHeatmapSnapshot(
            repositoryPath: URL(fileURLWithPath: path).standardizedFileURL.path,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            days: [ActivityHeatmapDay(date: Date(timeIntervalSince1970: 1_700_000_000), commitCount: count)]
        )
    }
}

@MainActor
private final class MockActivityHeatmapProvider: ActivityHeatmapProviding {
    var currentSnapshot: ActivityHeatmapSnapshot?
    var isLoading = false
    private var observer: ((ActivityHeatmapEvent) -> Void)?
    private var observerIsCancelled = false
    private(set) var refreshPaths: [String] = []

    func refresh(for repositoryURL: URL?) {
        if let repositoryURL { refreshPaths.append(repositoryURL.standardizedFileURL.path) }
        isLoading = true
    }

    func addObserver(
        _ callback: @escaping (ActivityHeatmapEvent) -> Void
    ) -> any ActivityHeatmapObserverHandle {
        observer = callback
        observerIsCancelled = false
        return MockActivityHeatmapObserverHandle { [weak self] in
            self?.observerIsCancelled = true
        }
    }

    func notify(_ event: ActivityHeatmapEvent) {
        guard !observerIsCancelled else { return }
        observer?(event)
    }
}

@MainActor
private final class MockActivityHeatmapObserverHandle: ActivityHeatmapObserverHandle {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel?()
        onCancel = nil
    }
}
