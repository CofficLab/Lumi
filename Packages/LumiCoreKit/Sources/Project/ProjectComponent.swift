import Combine
import Foundation

/// LumiCore 的"项目"功能组件。
///
/// 持有 `ProjectState`（真正的状态存储），对外暴露：
/// - 只读的 `currentProject` / `projects`（供 SwiftUI 视图、插件读取）
/// - 一组写方法（`switchToProject` / `addProject` / `removeProject` /
///   `clearCurrentProject` / `setCurrentProjectPath`），所有状态变更都经此入口
///
/// `ProjectState` 自身的 `currentProject` / `projects` 收敛为 `private(set)`，
/// 外部无法绕过本组件直接 mutate，保证"通过 Component 暴露功能"的封装边界。
///
/// 作为 `ObservableObject`，本组件把内部 `state.objectWillChange` 转发给自己，
/// 这样 `LumiCore` 只需订阅本组件一层（沿用既有 `subscribeToChild` 模式），
/// 即可在项目切换时收到刷新信号。
@MainActor
public final class ProjectComponent: ObservableObject {
    /// 真正的项目状态。`private(set)` 让外部可读不可替换,
    /// 写操作全部经本组件的方法门面。
    public private(set) var state: ProjectState

    private var stateSubscription: AnyCancellable?

    public init(state: ProjectState = ProjectState()) {
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

    // MARK: - 只读视图

    /// 当前打开的项目。等价于 `state.currentProject`,只读。
    public var currentProject: ProjectEntry? { state.currentProject }

    /// 已注册的项目列表。等价于 `state.projects`,只读。
    public var projects: [ProjectEntry] { state.projects }

    // MARK: - 写操作门面（转发到 state）

    /// 通过路径设置当前项目;若项目不在列表中,会自动创建条目。
    public func setCurrentProjectPath(_ path: String) {
        state.setCurrentProjectPath(path)
    }

    /// 切换到指定项目;若不在列表中,会添加到列表顶部。
    public func switchToProject(_ entry: ProjectEntry) {
        state.switchToProject(entry)
    }

    /// 清除当前项目(置 nil)。
    public func clearCurrentProject() {
        state.clearCurrentProject()
    }

    /// 添加项目到列表(已存在则更新)。
    public func addProject(_ entry: ProjectEntry) {
        state.addProject(entry)
    }

    /// 从列表移除项目;若移除的是当前项目,一并清除当前项目。
    public func removeProject(_ entry: ProjectEntry) {
        state.removeProject(entry)
    }
}
