import Combine

@MainActor
final class InputSettingsObserver {
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: InputSettingsViewModel, service: InputService = .shared) {
        service.$config
            .sink { [weak viewModel] config in viewModel?.apply(config: config) }
            .store(in: &cancellables)
        service.$availableInputSources
            .sink { [weak viewModel] sources in viewModel?.apply(availableSources: sources) }
            .store(in: &cancellables)
        viewModel.apply(config: service.config)
        viewModel.apply(availableSources: service.availableInputSources)
    }

    func cancel() {
        cancellables.removeAll()
    }
}
