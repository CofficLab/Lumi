import Foundation

/// Chat Toolbar ASC 面板需要的最小「App Store Connect」能力边界。
///
/// 只暴露本面板用到的三个只读查询，避免 ViewModel 直接依赖 `ConnectClient`。
@MainActor
protocol ASCChatClientCapability: AnyObject {
    /// 按 Bundle ID 查找 App；未命中时返回 `nil`。
    func findApp(bundleID: String) async throws -> AppStoreApp?

    /// 按 ASC App ID 读取 App。
    func readApp(id: String) async throws -> AppStoreApp

    /// 列出指定 App 的版本。
    func listVersions(appID: String) async throws -> [AppStoreVersion]
}

/// 将 ``ConnectClient`` 收窄为 ``ASCChatClientCapability``。
///
/// 客户端通过闭包惰性获取：`VM.configure(network:)` 会在运行期替换客户端实例，
/// 快照式持有会在替换后静默失效。
@MainActor
final class ASCChatClientCapabilityAdapter: ASCChatClientCapability {
    private let clientProvider: @MainActor () -> ConnectClient?

    init(clientProvider: @escaping @MainActor () -> ConnectClient?) {
        self.clientProvider = clientProvider
    }

    func findApp(bundleID: String) async throws -> AppStoreApp? {
        guard let client = clientProvider() else { throw ASCChatClientError.unavailable }
        return try await client.findApp(bundleID: bundleID)
    }

    func readApp(id: String) async throws -> AppStoreApp {
        guard let client = clientProvider() else { throw ASCChatClientError.unavailable }
        return try await client.readApp(id: id)
    }

    func listVersions(appID: String) async throws -> [AppStoreVersion] {
        guard let client = clientProvider() else { throw ASCChatClientError.unavailable }
        return try await client.listVersions(appID: appID)
    }
}

/// ASC 客户端不可用（未配置凭证 / 网络服务缺失）。
enum ASCChatClientError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        AppStoreConnectLocalization.string(
            "App Store Connect credentials are incomplete. Configure issuer ID, key ID, and private key in the App Store Connect plugin settings first."
        )
    }
}
