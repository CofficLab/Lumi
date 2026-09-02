#if os(iOS)
import Combine
import Foundation

/// Bridges BookletMakerViewModel changes to the mobile feature facade.
@MainActor
final class BookletMakerFeatureObserver {
    private var cancellable: AnyCancellable?

    init(viewModel: BookletMakerViewModel, onChange: @escaping () -> Void) {
        cancellable = viewModel.objectWillChange.sink { _ in
            onChange()
        }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}
#endif
