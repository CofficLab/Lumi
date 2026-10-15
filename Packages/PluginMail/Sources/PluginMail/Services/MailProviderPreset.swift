import Foundation

/// 常见邮件服务商预设（连接测试与表单默认值）。
///
/// 首版只支持密码登录（应用专用密码 / 授权码），不支持 OAuth2
/// （计划约束：后续版本再引入 refresh token 流程）。
public enum MailProviderPreset: String, CaseIterable, Identifiable, Sendable {
    case gmail
    case qq
    case netease163
    case icloud
    case outlook
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gmail: return "Gmail"
        case .qq: return "QQ 邮箱"
        case .netease163: return "网易 163"
        case .icloud: return "iCloud Mail"
        case .outlook: return "Outlook"
        case .custom: return "自定义"
        }
    }

    /// IMAP 主机（custom 由用户填写，返回 nil）。
    public var imapHost: String? {
        switch self {
        case .gmail: return "imap.gmail.com"
        case .qq: return "imap.qq.com"
        case .netease163: return "imap.163.com"
        case .icloud: return "imap.mail.me.com"
        case .outlook: return "outlook.office365.com"
        case .custom: return nil
        }
    }

    public var imapPort: Int {
        switch self {
        case .icloud: return 993
        case .outlook: return 993
        case .custom: return 993
        default: return 993
        }
    }

    /// SMTP 主机（custom 由用户填写，返回 nil）。
    public var smtpHost: String? {
        switch self {
        case .gmail: return "smtp.gmail.com"
        case .qq: return "smtp.qq.com"
        case .netease163: return "smtp.163.com"
        case .icloud: return "smtp.mail.me.com"
        case .outlook: return "smtp.office365.com"
        case .custom: return nil
        }
    }

    public var smtpPort: Int {
        switch self {
        case .gmail: return 465
        case .qq: return 465
        case .netease163: return 465
        case .icloud: return 587
        case .outlook: return 587
        case .custom: return 465
        }
    }

    /// 是否使用 SSL/TLS（iCloud/Outlook 走 STARTTLS 时仍可先用 SSL 端口）。
    public var useTLS: Bool {
        switch self {
        case .gmail: return true
        case .qq: return true
        case .netease163: return true
        case .icloud: return true
        case .outlook: return true
        case .custom: return true
        }
    }

    /// 用户名是否等同邮箱地址（Gmail/QQ/163/iCloud 是；Outlook/自定义由用户填）。
    public var usernameDefaultsToEmail: Bool {
        switch self {
        case .gmail, .qq, .netease163, .icloud: return true
        case .outlook, .custom: return false
        }
    }

    /// 由 IMAP 主机反推预设（编辑已有账户时恢复服务商下拉；无法匹配时返回 .custom）。
    public static func infer(imapHost: String) -> MailProviderPreset {
        let host = imapHost.lowercased()
        for preset in allCases {
            if let presetHost = preset.imapHost, presetHost.lowercased() == host {
                return preset
            }
        }
        return .custom
    }
}
