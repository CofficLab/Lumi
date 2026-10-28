import Foundation

/// 解析「项目 → 远程仓库 Web 链接」。
///
/// 这是标题栏按钮与 Agent 工具共用的核心逻辑：两者都只关心
/// 「当前项目的远程仓库在网页上是什么地址」，不关心 Git 细节与 UI。
///
/// 依赖通过窄能力协议注入，不直接持有 `any GitRepositoryReading`。
@MainActor
final class RemoteRepositoryResolver: @unchecked Sendable {
    /// 默认读取的 remote 名称。
    static let defaultRemote = "origin"

    private let gitCapability: any OpenInRemoteGitCapability

    init(gitCapability: any OpenInRemoteGitCapability) {
        self.gitCapability = gitCapability
    }

    /// 解析指定仓库路径对应的远程仓库 Web 链接。
    ///
    /// - Parameters:
    ///   - repositoryPath: 仓库路径。
    ///   - remote: remote 名称，默认 `origin`。
    /// - Returns: Web 链接；路径不是 Git 仓库、没有该 remote 或地址无法转换时返回 `nil`。
    func webURL(forRepositoryAt repositoryPath: String, remote: String = defaultRemote) async -> URL? {
        guard !repositoryPath.isEmpty else { return nil }
        guard let rawURL = await gitCapability.remoteURL(atPath: repositoryPath, remote: remote) else {
            return nil
        }
        return RemoteWebURLResolver.webURL(fromRemote: rawURL)
    }
}
