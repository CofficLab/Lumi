import Foundation
import ProviderProject

/// Editor Preview 插件需要的最小项目能力边界。
///
/// ViewModel 通过该协议读取当前选中文件，不直接持有
/// `ProjectProviding` 具体类型；Provider 的解析与适配由插件入口完成。
@MainActor
protocol EditorPreviewProjectCapability: AnyObject {
    /// 当前选中的文件。
    var currentFileURL: URL? { get }
}

/// 将内核的 `ProjectProviding` 收窄为 Editor Preview 插件的项目能力。
@MainActor
final class EditorPreviewProjectCapabilityAdapter: EditorPreviewProjectCapability {
    private let project: any ProjectProviding

    init(project: any ProjectProviding) {
        self.project = project
    }

    var currentFileURL: URL? { project.currentFileURL }
}
