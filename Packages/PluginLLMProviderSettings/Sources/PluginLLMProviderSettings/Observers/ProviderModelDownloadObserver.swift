import Combine
import Foundation
import KitLLM

/// Bridges provider download events into plugin-owned view state.
@MainActor
final class ProviderModelDownloadObserver {
    private var subscription: AnyCancellable?

    init(
        downloader: any LLMModelDownloadProviding,
        viewModel: ProviderModelDownloadViewModel
    ) {
        viewModel.apply(downloader.downloadState)
        subscription = downloader.downloadStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { state in
                viewModel.apply(state)
            }
    }

    func cancel() {
        subscription?.cancel()
        subscription = nil
    }
}
