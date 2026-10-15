import Foundation
import KitMail

/// 账户表单的可变编辑模型（添加/编辑共用）。
///
/// 提交时经 `toConfig(id:)` 转为 `MailAccountConfig`（不含密码，
/// 密码单独经 `MailAccountStore.setPassword` 写入 Keychain）。
public struct MailAccountDraft: Equatable, Sendable {
    public var provider: MailProviderPreset
    public var displayName: String
    public var email: String
    public var username: String
    public var password: String
    public var imapHost: String
    public var imapPort: Int
    public var smtpHost: String
    public var smtpPort: Int
    public var useTLS: Bool

    public init(
        provider: MailProviderPreset = .gmail,
        displayName: String = "",
        email: String = "",
        username: String = "",
        password: String = "",
        imapHost: String = "",
        imapPort: Int = 993,
        smtpHost: String = "",
        smtpPort: Int = 465,
        useTLS: Bool = true
    ) {
        self.provider = provider
        self.displayName = displayName
        self.email = email
        self.username = username
        self.password = password
        self.imapHost = imapHost
        self.imapPort = imapPort
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.useTLS = useTLS
    }

    /// 从已有配置初始化（编辑模式，密码从 Keychain 回填；服务商预设按 IMAP 主机推断）。
    public init(config: MailAccountConfig, password: String?) {
        self.init(
            provider: MailProviderPreset.infer(imapHost: config.imapHost),
            displayName: config.displayName,
            email: config.email,
            username: config.username,
            password: password ?? "",
            imapHost: config.imapHost,
            imapPort: Int(config.imapPort),
            smtpHost: config.smtpHost,
            smtpPort: Int(config.smtpPort),
            useTLS: config.useTLS
        )
    }

    /// 切换服务商预设时应用默认主机/端口（custom 保留用户填写）。
    public mutating func applyPresetDefaults() {
        if let host = provider.imapHost { imapHost = host }
        if let host = provider.smtpHost { smtpHost = host }
        imapPort = provider.imapPort
        smtpPort = provider.smtpPort
        useTLS = provider.useTLS
        if provider.usernameDefaultsToEmail, !email.isEmpty {
            username = email
        }
    }

    /// 转为正式账户配置（生成新 id 或保留编辑中的 id）。
    public func toConfig(id: UUID = UUID()) -> MailAccountConfig {
        MailAccountConfig(
            id: id,
            displayName: displayName.isEmpty ? email : displayName,
            email: email,
            imapHost: imapHost,
            imapPort: UInt16(imapPort),
            smtpHost: smtpHost,
            smtpPort: UInt16(smtpPort),
            username: username.isEmpty ? email : username,
            loginType: .password,
            useTLS: useTLS
        )
    }
}
