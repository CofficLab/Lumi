import Foundation
import ProviderProject

/// Open In 插件的项目变化事件。
///
/// 插件自有事件，不向消费方泄漏 `ProjectProvidingEvent`。
enum OpenInProjectEvent {
    /// 当前项目发生变化，`nil` 表示当前没有打开项目。
    case currentProjectChanged(String?)
}

/// Open In 插件对项目能力的观察句柄。
@MainActor
protocol OpenInProjectObserverHandle: AnyObject {
    /// 停止接收后续项目变更通知。重复调用无副作用。
    func cancel()
}

/// Open In 插件工具栏按钮需要的最小项目能力边界。
///
/// 标题栏 ViewModel 只关心「当前项目路径」和「项目切换事件」，
/// 不直接持有 `ProjectProviding` 宽接口；Provider 的解析与适配由插件入口完成。
@MainActor
protocol OpenInProjectCapability: AnyObject {
    /// 当前打开的项目路径，无项目时为 `nil`。
    var currentProjectPath: String? { get }

    /// 订阅项目变化事件，返回的句柄需在不再需要时 `cancel()`。
    func addProjectObserver(_ callback: @escaping (OpenInProjectEvent) -> Void) -> any OpenInProjectObserverHandle
}

/// 将内核的 `ProjectProviding` 收窄为 Open In 插件的项目能力。
///
/// - Note: `ProjectProviding` 允许为 `nil`（内核未注册项目能力时），
///   此时所有成员都退化为「无项目」语义，标题栏按钮自然保持禁用。
@MainActor
final class OpenInProjectCapabilityAdapter: OpenInProjectCapability {
    private let project: (any ProjectProviding)?

    init(project: (any ProjectProviding)?) {
        self.project = project
    }

    var currentProjectPath: String? { project?.currentProject?.path }

    func addProjectObserver(_ callback: @escaping (OpenInProjectEvent) -> Void) -> any OpenInProjectObserverHandle {
        guard let project else {
            return OpenInNoopObserverHandle()
        }
        return OpenInObserverHandleBox(
            project.addObserver { event in
                guard case let .currentProjectChanged(currentProject, _) = event else { return }
                callback(.currentProjectChanged(currentProject?.path))
            }
        )
    }
}

/// 包装 Provider 的观察句柄，避免把 Provider 的句柄类型泄漏给消费方。
@MainActor
private final class OpenInObserverHandleBox: OpenInProjectObserverHandle {
    private let handle: any ProjectProvidingObserverHandle

    init(_ handle: any ProjectProvidingObserverHandle) {
        self.handle = handle
    }

    func cancel() {
        handle.cancel()
    }
}

/// 无 Provider 时的空句柄。
@MainActor
private final class OpenInNoopObserverHandle: OpenInProjectObserverHandle {
    func cancel() {}
}
