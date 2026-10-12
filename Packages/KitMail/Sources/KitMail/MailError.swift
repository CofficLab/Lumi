import Foundation

/// 邮件统一错误。
///
/// 每个 case 提供可本地化描述键（`localizedDescriptionKey`），UI 层经
/// `LumiLocalization` 翻译；不得向日志输出完整凭据或正文。
public enum MailError: Error, Sendable, Codable, Hashable {
    /// 认证失败（密码错误 / 授权码失效 / OAuth 过期）
    case authFailed
    /// 网络错误（连接失败 / 超时 / 断网）
    case network
    /// 协议错误（服务器返回异常响应）
    case protocolError(String)
    /// 对象不存在（uid / 文件夹不存在）
    case notFound
    /// 离线（无缓存且不可达）
    case offline
    /// 暂不支持的能力（如 OAuth2 首版未实现、POP3 明确不做）
    case unsupported(String)

    /// 本地化描述键（`Mail.Error.AuthFailed` 等），供 xcstrings 使用。
    public var localizedDescriptionKey: String {
        switch self {
        case .authFailed: return "Mail.Error.AuthFailed"
        case .network: return "Mail.Error.Network"
        case .protocolError: return "Mail.Error.Protocol"
        case .notFound: return "Mail.Error.NotFound"
        case .offline: return "Mail.Error.Offline"
        case .unsupported: return "Mail.Error.Unsupported"
        }
    }

    /// 用户可读文案（无本地化时的兜底英文；本地化走 `localizedDescriptionKey`）。
    public var fallbackDescription: String {
        switch self {
        case .authFailed: return "Authentication failed. Check your password or app password."
        case .network: return "Network error. Check your connection."
        case .protocolError(let detail): return "Mail server protocol error: \(detail)"
        case .notFound: return "The requested message or folder was not found."
        case .offline: return "You are offline. Showing cached messages."
        case .unsupported(let feature): return "Not supported: \(feature)"
        }
    }

    /// 供日志使用的短标签（不含任何凭据）。
    public var logLabel: String {
        switch self {
        case .authFailed: return "authFailed"
        case .network: return "network"
        case .protocolError: return "protocol"
        case .notFound: return "notFound"
        case .offline: return "offline"
        case .unsupported: return "unsupported"
        }
    }
}
