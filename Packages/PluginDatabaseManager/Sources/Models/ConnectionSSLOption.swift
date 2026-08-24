import Foundation

/// 连接的 SSL/TLS 模式。值存进 ``DatabaseConfig/options`` 的 `"ssl"` 键，
/// 驱动层据此决定是否启用 TLS。
///
/// 语义对齐 PostgreSQL 的 `sslmode`（业内最通用），MySQL 驱动做等价映射。
public enum ConnectionSSLOption: String, CaseIterable, Sendable {
    /// 不加密（明文）。等价 PG `disable` / MySQL `DISABLED`。
    case disable
    /// 尽可能加密，失败则回退明文（PG `prefer` / MySQL `PREFERRED`）。
    case prefer
    /// 必须加密，但不校验证书（PG `require` / MySQL `REQUIRED`）。
    /// 适合自签证书或 dev 服务器。
    case require
    /// 必须加密且校验 CA（PG `verify-ca` / MySQL `VERIFY_CA`）。
    case verifyCA = "verify-ca"
    /// 必须加密且校验 CA + 主机名（PG `verify-full` / MySQL `VERIFY_IDENTITY`）。
    case verifyFull = "verify-full"

    public var displayTitle: String {
        switch self {
        case .disable: return "Disable"
        case .prefer: return "Prefer"
        case .require: return "Require"
        case .verifyCA: return "Verify CA"
        case .verifyFull: return "Verify Full"
        }
    }

    public var helpText: String {
        switch self {
        case .disable: return "No encryption."
        case .prefer: return "Encrypt if available, fallback to plain."
        case .require: return "Always encrypt, skip certificate check (self-signed OK)."
        case .verifyCA: return "Encrypt and verify the server certificate authority."
        case .verifyFull: return "Encrypt and verify CA + hostname (most strict)."
        }
    }
}

public extension DatabaseConfig {
    private static let sslOptionKey = "ssl"

    /// 当前配置的 SSL 模式。未设置时返回 nil（驱动按各自默认行为处理）。
    var sslOption: ConnectionSSLOption? {
        guard let raw = options?[Self.sslOptionKey] else { return nil }
        return ConnectionSSLOption(rawValue: raw)
    }

    /// 返回一份应用了新 SSL 模式的副本（nil 表示移除该选项，回退默认）。
    func withSSLOption(_ mode: ConnectionSSLOption?) -> DatabaseConfig {
        var copy = self
        var opts = copy.options ?? [:]
        if let mode {
            opts[Self.sslOptionKey] = mode.rawValue
        } else {
            opts.removeValue(forKey: Self.sslOptionKey)
        }
        copy.options = opts.isEmpty ? nil : opts
        return copy
    }
}
