import Combine
import Foundation

/// LumiCore 的"布局"功能组件。
@MainActor
public final class LayoutComponent: ObservableObject {
    public private(set) var state: LayoutState

    private var stateSubscription: AnyCancellable?

    public init(state: LayoutState = LayoutState()) {
        self.state = state
        subscribeToState()
    }

    private func subscribeToState() {
        stateSubscription = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
