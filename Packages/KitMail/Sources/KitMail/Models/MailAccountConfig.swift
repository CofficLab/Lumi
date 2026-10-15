import Foundation

/// 邮件登录方式。
public enum MailLoginType: String, Sendable, Codable, CaseIterable {
    /// 密码 / 应用专用密码 / 授权码（首版唯一支持）
    case password
    /// OAuth2（Phase 6 可选增强，`MailSessionServing` 已预留 refresh token 存储位）
    case oauth2
}

/// 邮件账户配置（**不含密码 / refresh token**，凭据存系统 Keychain）。
///
/// 存储形式：`StorageProviding.pluginDataDirectory(for:)/accounts.json`，
/// 遵循 [插件数据存储规范] 中「配置不含密码」的要求。
public struct MailAccountConfig: Sendable, Codable, Identifiable, Hashable {
    public var id: UUID
    public var displayName: String
    public var email: String
    public var imapHost: String
    public var imapPort: UInt16
    public var smtpHost: String
    public var smtpPort: UInt16
    public var username: String
    /// 登录方式；`oauth2` 为 Phase 6 预留，首版表单不暴露
    public var loginType: MailLoginType
    /// IMAP/SMTP 是否强制 TLS（true）或 STARTTLS（false）
    public var useTLS: Bool

    public init(
        id: UUID = UUID(),
        displayName: String,
        email: String,
        imapHost: String,
        imapPort: UInt16 = 993,
        smtpHost: String,
        smtpPort: UInt16 = 465,
        username: String,
        loginType: MailLoginType = .password,
        useTLS: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.imapHost = imapHost
        self.imapPort = imapPort
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.username = username
        self.loginType = loginType
        self.useTLS = useTLS
    }
}
