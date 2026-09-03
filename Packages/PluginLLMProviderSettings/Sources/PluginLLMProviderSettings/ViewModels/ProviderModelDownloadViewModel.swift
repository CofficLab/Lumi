import Combine
import Foundation
import KitLLM

/// View state for a provider's model download panel.
@MainActor
public final class ProviderModelDownloadViewModel: ObservableObject {
    @Published public private(set) var downloadState: LLMModelDownloadState

    public init(initialState: LLMModelDownloadState = .init()) {
        downloadState = initialState
    }

    func apply(_ state: LLMModelDownloadState) {
        guard downloadState != state else { return }
        downloadState = state
    }
}
