#if os(iOS)
import Combine
import Foundation

/// Bridges BookletMakerViewModel and MobileWorkspaceState changes to the mobile feature facade.
@MainActor
final class BookletMakerFeatureObserver {
    private var viewModelCancellable: AnyCancellable?
    private var workspaceCancellable: AnyCancellable?

    init(viewModel: BookletMakerViewModel, workspace: MobileWorkspaceState, onChange: @escaping () -> Void) {
        // 监听 viewModel 的变化（文档、设置等）
        viewModelCancellable = viewModel.objectWillChange.sink { _ in
            onChange()
        }
        
        // 监听 workspace 的变化（工具切换、阶段变化等）
        // 使用 DispatchQueue.main.async 延迟发送，避免在视图更新期间触发 objectWillChange。
        workspaceCancellable = workspace.objectWillChange.sink { _ in
            DispatchQueue.main.async {
                onChange()
            }
        }
    }

    func cancel() {
        viewModelCancellable?.cancel()
        viewModelCancellable = nil
        workspaceCancellable?.cancel()
        workspaceCancellable = nil
    }
}
#endif
