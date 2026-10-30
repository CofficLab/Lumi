import Foundation
import ProviderProject

/// Memory 插件工具需要的最小项目能力边界。
///
/// 记忆工具只按当前项目路径分域存取，不需要项目的打开 / 关闭等完整能力。
@MainActor
protocol MemoryProjectCapability: AnyObject {
    /// 当前打开的项目路径，无项目时为 `nil`（对应「全局记忆」域）。
    var currentProjectPath: String? { get }
}

/// 将内核的 `ProjectProviding` 收窄为 Memory 插件的项目能力。
@MainActor
final class MemoryProjectCapabilityAdapter: MemoryProjectCapability {
    private let project: (any ProjectProviding)?

    init(project: (any ProjectProviding)?) {
        self.project = project
    }

    var currentProjectPath: String? { project?.currentProject?.path }
}
