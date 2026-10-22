import Foundation
import ProviderProject

/// Chat Toolbar 的项目窄能力协议。
///
/// 覆盖「点击文件跳到文件树」所需的最小面：只需把仓库内的相对路径
/// 拼成绝对 URL 并以预览方式交给宿主。不暴露 `ProjectProviding` 的其余成员，
/// 避免 ViewModel 与宽 Provider 耦合。
@MainActor
public protocol GitChatProjectCapability: AnyObject, Sendable {
    /// 以预览方式打开仓库内的文件（不固定到「已打开文件」列表）。
    ///
    /// - Parameters:
    ///   - repositoryPath: 仓库根目录绝对路径。
    ///   - relativePath: 仓库内相对路径。
    func previewFile(inRepositoryAt repositoryPath: String, relativePath: String)
}

/// 将 `ProjectProviding` 收窄为 ``GitChatProjectCapability``。
@MainActor
public final class GitChatProjectCapabilityAdapter: GitChatProjectCapability, @unchecked Sendable {
    private let project: (any ProjectProviding)?

    public init(project: (any ProjectProviding)?) {
        self.project = project
    }

    public func previewFile(inRepositoryAt repositoryPath: String, relativePath: String) {
        guard let project else { return }
        let url = URL(fileURLWithPath: repositoryPath).appendingPathComponent(relativePath)
        project.previewFile(url)
    }
}
