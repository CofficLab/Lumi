import Foundation

/// 邮件地址：显示名 + 邮箱。
///
/// 对应 MailCore `MCOAddress`。空显示名时 `displayName == nil`，
/// 序列化与比较只依赖 `email` 的归一化形式。
public struct MailAddress: Sendable, Codable, Hashable, Identifiable {
    public var displayName: String?
    public var email: String

    public init(displayName: String?, email: String) {
        self.displayName = displayName
        self.email = email
    }

    public var id: String { email }

    /// 相等性只依赖邮箱（同一邮箱地址即视为同一联系人，
    /// 显示名差异不改变身份）。
    public static func == (lhs: MailAddress, rhs: MailAddress) -> Bool {
        lhs.email == rhs.email
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(email)
    }

    /// RFC 5322 地址形式：`"Display Name" <user@example.com>`；
    /// 无显示名时仅返回邮箱。
    public var rfc5322: String {
        guard let displayName, !displayName.isEmpty else { return email }
        let escaped = displayName
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\" <\(email)>"
    }
}
