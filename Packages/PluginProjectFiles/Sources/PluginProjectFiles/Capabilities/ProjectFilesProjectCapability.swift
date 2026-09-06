import Foundation
import ProviderProject

/// Project Files 插件需要的最小项目能力边界。
///
/// ViewModel / TabState 通过该协议读写当前项目的打开文件状态，
/// 不直接持有 `ProjectProviding` 具体类型；Provider 的解析与适配由插件入口完成。
@MainActor
protocol ProjectFilesProjectCapability: AnyObject {
    /// 当前打开的项目。
    var currentProject: ProjectInfo? { get }

    /// 当前项目已打开的文件。
    var openFileURLs: [URL] { get }

    /// 当前选中的文件。
    var currentFileURL: URL? { get }

    /// 激活已打开文件，不改变打开文件列表。
    func activateFile(_ fileURL: URL)

    /// 关闭指定文件（从打开文件列表中移除）。
    func closeFile(_ fileURL: URL)

    /// 更新当前文件。
    func updateCurrentFile(_ fileURL: URL?)
}

/// 将内核的 `ProjectProviding` 收窄为 Project Files 插件的项目能力。
@MainActor
final class ProjectFilesProjectCapabilityAdapter: ProjectFilesProjectCapability {
    private let project: any ProjectProviding

    init(project: any ProjectProviding) {
        self.project = project
    }

    var currentProject: ProjectInfo? { project.currentProject }

    var openFileURLs: [URL] { project.openFileURLs }

    var currentFileURL: URL? { project.currentFileURL }

    func activateFile(_ fileURL: URL) {
        project.activateFile(fileURL)
    }

    func closeFile(_ fileURL: URL) {
        project.closeFile(fileURL)
    }

    func updateCurrentFile(_ fileURL: URL?) {
        project.updateCurrentFile(fileURL)
    }
}
