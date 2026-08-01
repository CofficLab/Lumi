import Combine
import Foundation
import LumiKernel

/// 观察内核 `ProjectProviding` 当前项目路径变化的轻量适配器。
///
/// `ProjectProviding` 是 `ObservableObject` 协议存在类型，无法直接用于 `@ObservedObject`
/// （`type 'any ProjectProviding' cannot conform to 'ObservableObject'`）。这里订阅其
/// `objectWillChange`（通过 `.eraseToAnyPublisher()` 擦除存在类型发布者），把当前项目路径
/// 缓存为 `@Published`，供视图响应式读取。
@MainActor
final class ProjectPathObserver: ObservableObject {
    @Published private(set) var path: String = ""

    private var cancellable: AnyCancellable?

    init(project: any ProjectProviding) {
        self.path = project.currentProject?.path ?? ""
        self.cancellable = project.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .sink { [weak self] _ in
                guard let self else { return }
                let newPath = project.currentProject?.path ?? ""
                guard newPath != self.path else { return }
                self.path = newPath
            }
    }
}
