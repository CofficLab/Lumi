import Foundation

/// PluginMail 插件级本地设置存储。
///
/// 与账户数据（`MailAccountStore`）分离：这里只放 UI 级偏好
/// （如远程图片加载确认、未读角标开关等），账户配置与密码
/// 一律走 `MailAccountStore`（JSON + Keychain）。
public final class MailPluginLocalStore: @unchecked Sendable {
    public static let shared = MailPluginLocalStore()

    private static let suiteName = "com.coffic.lumi.plugin.mail.local"
    private let suiteName: String
    private let defaults: UserDefaults

    public init(suiteName: String = "com.coffic.lumi.plugin.mail.local") {
        self.suiteName = suiteName
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - 偏好项

    /// 加载 HTML 邮件正文前是否要求用户确认（病毒防护：禁 JS、默认不加载远程图片）。
    public var confirmBeforeLoadingHTML: Bool {
        get { defaults.bool(forKey: "confirmBeforeLoadingHTML") }
        set { defaults.set(newValue, forKey: "confirmBeforeLoadingHTML") }
    }

    /// 邮件列表未读角标开关。
    public var unreadBadgeEnabled: Bool {
        get {
            defaults.object(forKey: "unreadBadgeEnabled") == nil
                ? true
                : defaults.bool(forKey: "unreadBadgeEnabled")
        }
        set { defaults.set(newValue, forKey: "unreadBadgeEnabled") }
    }

    // MARK: - 测试隔离

    public func reset() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
