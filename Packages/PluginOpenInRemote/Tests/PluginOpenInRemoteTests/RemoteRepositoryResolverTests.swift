import Foundation
import ProviderGit
import Testing
@testable import PluginOpenInRemote

/// 锁定「仓库路径 → 远程仓库 web 链接」的解析链路。
@Suite("RemoteRepositoryResolver")
@MainActor
struct RemoteRepositoryResolverTests {
    /// 测试替身：按路径返回预设的 remote URL。
    private final class StubGitCapability: OpenInRemoteGitCapability, @unchecked Sendable {
        private let remoteURLs: [String: String]
        private(set) var requestedRemotes: [String] = []

        init(remoteURLs: [String: String]) {
            self.remoteURLs = remoteURLs
        }

        func remoteURL(atPath path: String, remote: String) async -> String? {
            requestedRemotes.append(remote)
            return remoteURLs[path]
        }
    }

    @Test("读取 origin remote 并转换为 web 链接")
    func resolvesWebURLFromOriginRemote() async {
        let git = StubGitCapability(remoteURLs: ["/repo": "git@github.com:user/repo.git"])
        let resolver = RemoteRepositoryResolver(gitCapability: git)

        let url = await resolver.webURL(forRepositoryAt: "/repo")

        #expect(url?.absoluteString == "https://github.com/user/repo")
        #expect(git.requestedRemotes == ["origin"])
    }

    @Test("指定 remote 名称时按名称读取")
    func resolvesWebURLFromNamedRemote() async {
        let git = StubGitCapability(remoteURLs: ["/repo": "https://github.com/user/upstream.git"])
        let resolver = RemoteRepositoryResolver(gitCapability: git)

        let url = await resolver.webURL(forRepositoryAt: "/repo", remote: "upstream")

        #expect(url?.absoluteString == "https://github.com/user/upstream")
        #expect(git.requestedRemotes == ["upstream"])
    }

    @Test("仓库没有 remote 地址时返回 nil")
    func returnsNilWhenRemoteIsMissing() async {
        let git = StubGitCapability(remoteURLs: [:])
        let resolver = RemoteRepositoryResolver(gitCapability: git)

        #expect(await resolver.webURL(forRepositoryAt: "/repo") == nil)
    }

    @Test("remote 地址无法转换为 web 链接时返回 nil")
    func returnsNilWhenRemoteIsNotConvertible() async {
        let git = StubGitCapability(remoteURLs: ["/repo": "not-a-remote"])
        let resolver = RemoteRepositoryResolver(gitCapability: git)

        #expect(await resolver.webURL(forRepositoryAt: "/repo") == nil)
    }

    @Test("空路径不触发读取")
    func skipsLookupForEmptyPath() async {
        let git = StubGitCapability(remoteURLs: [:])
        let resolver = RemoteRepositoryResolver(gitCapability: git)

        #expect(await resolver.webURL(forRepositoryAt: "") == nil)
        #expect(git.requestedRemotes.isEmpty)
    }

    @Test("缺少 Git 能力时安全降级为 nil")
    func degradesGracefullyWithoutGitProvider() async {
        let resolver = RemoteRepositoryResolver(
            gitCapability: OpenInRemoteGitCapabilityAdapter(provider: nil)
        )

        #expect(await resolver.webURL(forRepositoryAt: "/repo") == nil)
    }
}
