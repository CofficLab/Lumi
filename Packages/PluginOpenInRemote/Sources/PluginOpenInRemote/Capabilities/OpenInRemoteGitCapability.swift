import Foundation
import ProviderGit

/// Open In Remote 插件的 Git 窄能力协议。
///
/// 遵循「插件 Capabilities 能力边界规范」：ViewModel / Tool 只面向本协议，
/// 不直接持有 `any GitRepositoryReading`。插件入口在 `onBoot` 创建
/// `OpenInRemoteGitCapabilityAdapter` 并注入。
///
/// 协议继承 `AnyObject` 以便消费方以弱引用持有，避免入口与 ViewModel
/// 形成循环引用（与 `PluginGitChatToolbar` 的 `GitChatCapability` 同一定位）。
@MainActor
protocol OpenInRemoteGitCapability: AnyObject, Sendable {
    /// 读取仓库的远程地址（原始 URL）；仓库不存在或无该 remote 时返回 `nil`。
    func remoteURL(atPath path: String, remote: String) async -> String?
}

/// 将 `GitRepositoryReading` 收窄为 ``OpenInRemoteGitCapability``。
///
/// 适配器由插件入口持有；`GitRepositoryReading` 契约实例由内核服务注册表持有，
/// 二者不构成循环引用。
@MainActor
final class OpenInRemoteGitCapabilityAdapter: OpenInRemoteGitCapability, @unchecked Sendable {
    private let provider: (any GitRepositoryReading)?

    init(provider: (any GitRepositoryReading)?) {
        self.provider = provider
    }

    func remoteURL(atPath path: String, remote: String) async -> String? {
        guard let provider else { return nil }
        return await provider.remoteURL(atPath: path, remote: remote)
    }
}
