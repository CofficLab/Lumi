import Combine
import Foundation

/// LumiCore 的"布局"功能组件。
///
/// 持有 `LumiLayoutState`（真正的状态存储）。作为 `ObservableObject`,把内部
/// `state.objectWillChange` 转发给自己,这样 `LumiCore` 只需订阅本组件一层
/// (沿用既有 `subscribeToChild` 模式),即可在布局状态变化时收到刷新信号。
///
/// ## 与 ProjectComponent 的差异
///
/// `ProjectComponent` 把写操作全部收敛进 5 个门面方法,外部不能直接 mutate state 字段。
/// 本组件**不收敛**——`LumiLayoutState` 的 `activeViewContainerID` / `chatSectionVisible` /
/// `bottomPanelVisible` / `activeRailTabID` 等核心字段保持 `@Published public var`,
/// 外部(含 SwiftUI `Binding` 的 set 路径、`LayoutPlugin` 的 restore 路径)可直接赋值。
/// 理由:SwiftUI 的 `Binding` / `@ObservedObject` 惯法天然要求外部能写字段,
/// 强行收敛成 `private(set)` 会违背 SwiftUI 设计并产生大量 setter 样板。
///
/// 因此本组件采用**最小门面 + state 暴露**策略:
/// - 暴露 `public private(set) var state`(外部可读 state 实例,不可替换)
/// - 转发 `objectWillChange`(让 LumiCore 能订阅它)
/// - 不做 30 个方法转发——外部需要调 state 方法时直接走 `component.state.xxx()`
@MainActor
public final class LayoutComponent: ObservableObject {
    /// 真正的布局状态。`private(set)` 让外部可读不可替换。
    public private(set) var state: LumiLayoutState

    private var stateSubscription: AnyCancellable?

    public init(state: LumiLayoutState = LumiLayoutState()) {
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
