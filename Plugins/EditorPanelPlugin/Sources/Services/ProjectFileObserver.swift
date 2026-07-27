import Combine
import LumiKernel

/// 转发 `ProjectProviding` 变化的观察器。
///
/// `any ProjectProviding` 无法直接作为 `@ObservedObject`，故用一个 `ObservableObject`
/// 订阅其 `objectWillChange` 并转发，让 SwiftUI 在 project 变化时刷新视图。
final class ProjectFileObserver: ObservableObject {
    var project: (any ProjectProviding)?
    private var cancellable: AnyCancellable?

    init(project: any ProjectProviding) {
        self.project = project
        bind()
    }

    private func bind() {
        cancellable = project?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
