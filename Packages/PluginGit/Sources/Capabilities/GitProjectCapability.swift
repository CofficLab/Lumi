import Foundation
import ProviderProject

/// Git 插件工具需要的最小项目能力边界。
///
/// Agent 工具通过该协议读取当前项目路径来定位 Git 仓库，
/// 不直接持有 `ProjectProviding` 具体类型；Provider 的解析与适配由插件入口完成。
@MainActor
public protocol GitProjectCapability: AnyObject {
    /// 当前项目路径（未打开项目时为 nil）。
    var currentProjectPath: String? { get }
}

/// 将内核的 `ProjectProviding` 收窄为 Git 插件的项目路径能力。
@MainActor
public final class GitProjectCapabilityAdapter: GitProjectCapability {
    private let project: any ProjectProviding

    public init(project: any ProjectProviding) {
        self.project = project
    }

    public var currentProjectPath: String? { project.currentProject?.path }
}
