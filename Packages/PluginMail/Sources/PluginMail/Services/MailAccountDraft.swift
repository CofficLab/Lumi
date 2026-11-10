import Foundation
import KitMail

/// 账户表单校验错误。
public enum MailAccountDraftError: Error, Equatable, LocalizedError {
    /// 端口不在 1...65535 内。
    case invalidPort(field: String, value: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidPort(let field, let value):
            return "\(field) port must be between 1 and 65535 (got \(value))."
        }
    }
}

/// 账户表单的可变编辑模型（添加/编辑共用）。
///
/// 提交时经 `toConfig(id:)` 转为 `MailAccountConfig`（不含密码，
/// 密码单独经 `MailAccountStore.setPassword` 写入 Keychain）。
public struct MailAccountDraft: Equatable, Sendable {
    /// 端口合法范围：0 不是可连接端口，65535 是 `UInt16` 上限。
    public static let validPortRange = 1...Int(UInt16.max)
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

    /// 新建账户草稿：主机、端口与 TLS 立即与选中的服务商预设一致。
    ///
    /// 表单只在 Picker 变化时调用 `applyPresetDefaults()`，初始展示不会触发
    /// 变更回调；因此新建路径必须在构造时就填好预设值。
    public static func forNewAccount(provider: MailProviderPreset = .gmail) -> MailAccountDraft {
        var draft = MailAccountDraft(provider: provider)
        draft.applyPresetDefaults()
        return draft
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

    /// 端口是否在可连接范围内。
    public static func isValidPort(_ port: Int) -> Bool {
        validPortRange.contains(port)
    }

    /// IMAP 与 SMTP 端口是否都合法。
    public var hasValidPorts: Bool {
        Self.isValidPort(imapPort) && Self.isValidPort(smtpPort)
    }

    /// 转为正式账户配置（生成新 id 或保留编辑中的 id）。
    ///
    /// 端口越界时抛 `MailAccountDraftError.invalidPort`，绝不执行可陷阱的
    /// `UInt16(_:)` 强制转换。
    public func toConfig(id: UUID = UUID()) throws -> MailAccountConfig {
        guard let imap = UInt16(exactly: imapPort), imap > 0 else {
            throw MailAccountDraftError.invalidPort(field: "IMAP", value: imapPort)
        }
        guard let smtp = UInt16(exactly: smtpPort), smtp > 0 else {
            throw MailAccountDraftError.invalidPort(field: "SMTP", value: smtpPort)
        }
        return MailAccountConfig(
            id: id,
            displayName: displayName.isEmpty ? email : displayName,
            email: email,
            imapHost: imapHost,
            imapPort: imap,
            smtpHost: smtpHost,
            smtpPort: smtp,
            username: username.isEmpty ? email : username,
            loginType: .password,
            useTLS: useTLS
        )
    }
}
