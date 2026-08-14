import Combine
import KernelLumi

/// 将 `ProjectProviding` 的变化转发给 SwiftUI。
///
/// 协议存在类型无法直接用作 `@ObservedObject`，因此这里只负责
/// 触发重算；是否存在当前项目始终从项目服务实时读取。
@MainActor
final class RailProjectObserver: ObservableObject {
    private let project: (any ProjectProviding)?
    private var cancellable: AnyCancellable?

    var hasActiveProject: Bool {
        project?.currentProject != nil
    }

    init(project: (any ProjectProviding)?) {
        self.project = project
        cancellable = project?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
