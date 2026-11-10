import Combine
import ProviderProject

/// 设置页展示的项目状态。
///
/// 设置入口由插件在启动时注册，不能把当时的 `currentProject.path` 固化成
/// 不可变字符串；这里订阅项目切换事件，让设置页始终跟随真实的当前项目。
@MainActor
final class QuickFileSearchSettingsStatus: ObservableObject {
    @Published private(set) var projectPath: String = ""

    private var projectHandle: (any ProjectProvidingObserverHandle)?

    init(project: (any ProjectProviding)?) {
        projectPath = project?.currentProject?.path ?? ""
        projectHandle = project?.addObserver { [weak self] event in
            guard case let .currentProjectChanged(project, _) = event else { return }
            self?.projectPath = project?.path ?? ""
        }
    }
}
