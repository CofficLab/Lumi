import Combine
import Foundation

/// LumiCore 的"布局"功能组件。
@MainActor
public final class LayoutComponent: ObservableObject {
    /// 真正的布局状态。`private(set)` 让外部可读不可替换。
    public private(set) var state: LayoutState

    private var stateSubscription: AnyCancellable?

    public init(state: LayoutState = LayoutState()) {
        self.state = state
        subscribeToState()
    }

    /// 订阅 `state.objectWillChange` 并转发给本组件,
    /// 让 `@ObservedObject` 本组件的视图能感知 `state` 内部字段变化。
    private func subscribeToState() {
        stateSubscription = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
