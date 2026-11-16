import Foundation

/// 一台远程服务器的 SSH 连接配置。
///
/// 只保存连接参数，不保存任何秘密：密钥口令由 ssh-agent / Keychain 托管，
/// 认证默认走 `~/.ssh` 现有配置。
public struct ServerConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var user: String
    public var group: String
    /// 可选的私钥路径；为空时使用 ssh 默认查找顺序。
    public var identityFile: String?

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        user: String,
        group: String = "Default",
        identityFile: String? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.user = user
        self.group = group
        self.identityFile = identityFile
    }

    /// ssh 目标（`user@host`），也兼容 `~/.ssh/config` 别名。
    public var destination: String { "\(user)@\(host)" }
}