import Combine
import LumiKernel

/// 面包屑导航对 `ProjectProviding` 的订阅适配器。
///
/// 转发 `project.objectWillChange` 到自身的 `objectWillChange`，让 SwiftUI 视图响应
/// 当前文件路径或项目变化。视图在 body 内实时读取 `kernel.project?.currentFileURL`，
/// 天然规避 Combine `objectWillChange` 触发时值仍为旧的陷阱。
///
/// 范式参考 `ProjectFilesState.ProjectFilesProjectObserver`。
@MainActor
final class ProjectFileBreadcrumbObserver: ObservableObject {
    private var cancellable: AnyCancellable?

    init(project: (any ProjectProviding)?) {
        bind(project)
    }

    private func bind(_ project: (any ProjectProviding)?) {
        cancellable = project?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
