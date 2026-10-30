import Foundation

/// 供应商端点地址的安全策略。
///
/// ## 要解决的问题
///
/// 供应商配置里的 `baseURL` 决定了后续所有请求发往哪里。一旦这个值由
/// LLM 决定而不是用户决定，它就成了一个**任意外连通道**：把 baseURL 指向
/// 某个内网服务，用户的对话内容与凭据就会被送到那里。
///
/// ## 策略
///
/// | 目标 | 判定 | 允许的协议 |
/// |------|------|-----------|
/// | 回环地址（`localhost` / `127.0.0.0/8` / `::1`） | 本机 | `http` 或 `https` |
/// | 其它地址 | 远端 | 仅 `https` |
///
/// 私网网段（`10/8`、`172.16/12`、`192.168/16`）、链路本地（`169.254/16`）
/// 与 `.local` 域名一律拒绝——它们既是最常见的内网探测目标，也没有
/// 「公网服务必须走 https」这种自证能力。
enum ProviderEndpointPolicy {

    /// 校验一个 baseURL 是否可作为供应商端点。
    ///
    /// - Parameter baseURL: 待校验的地址。
    /// - Returns: 校验通过后的规范化地址。
    /// - Throws: `ProviderEndpointPolicyError` 描述具体违规原因。
    static func validate(baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              let host = url.host, !host.isEmpty else {
            throw ProviderEndpointPolicyError.invalidURL
        }

        guard scheme == "https" || scheme == "http" else {
            throw ProviderEndpointPolicyError.unsupportedScheme(scheme)
        }

        if isLoopback(host: host) {
            return url
        }

        if isPrivateNetwork(host: host) {
            throw ProviderEndpointPolicyError.privateNetworkAddress(host)
        }

        guard scheme == "https" else {
            throw ProviderEndpointPolicyError.insecureRemoteEndpoint(host)
        }

        return url
    }

    /// 主机是否指向本机。
    static func isLoopback(host: String) -> Bool {
        let normalized = host.lowercased()
        if normalized == "localhost" || normalized.hasSuffix(".localhost") {
            return true
        }
        if normalized == "::1" || normalized == "[::1]" {
            return true
        }
        if let octets = ipv4Octets(host: normalized), octets[0] == 127 {
            return true
        }
        return false
    }

    /// 主机是否位于私网 / 链路本地网段。
    static func isPrivateNetwork(host: String) -> Bool {
        let normalized = host.lowercased()
        if normalized.hasSuffix(".local") {
            return true
        }
        if let octets = ipv4Octets(host: normalized) {
            // 10/8
            if octets[0] == 10 { return true }
            // 172.16/12
            if octets[0] == 172, (16...31).contains(octets[1]) { return true }
            // 192.168/16
            if octets[0] == 192, octets[1] == 168 { return true }
            // 169.254/16 链路本地
            if octets[0] == 169, octets[1] == 254 { return true }
            // 0/8 与 100.64/10（CGNAT）同样属于内部保留段
            if octets[0] == 0 { return true }
            if octets[0] == 100, (64...127).contains(octets[1]) { return true }
            return false
        }
        // IPv6：唯一本地地址 fc00::/7 与链路本地 fe80::/10
        if normalized.contains(":") {
            if normalized.hasPrefix("fc") || normalized.hasPrefix("fd") { return true }
            if normalized.hasPrefix("fe8") || normalized.hasPrefix("fe9")
                || normalized.hasPrefix("fea") || normalized.hasPrefix("feb") {
                return true
            }
        }
        return false
    }

    /// 解析 IPv4 字面量为四段八进制数值；不是 IPv4 字面量时返回 `nil`。
    private static func ipv4Octets(host: String) -> [Int]? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var octets: [Int] = []
        for part in parts {
            guard let value = Int(part), (0...255).contains(value), !part.isEmpty else { return nil }
            octets.append(value)
        }
        return octets
    }
}

/// 端点策略的拒绝原因。
enum ProviderEndpointPolicyError: LocalizedError, Equatable, Sendable {
    /// 地址无法解析，或缺少主机名。
    case invalidURL
    /// 协议不受支持（只接受 http / https）。
    case unsupportedScheme(String)
    /// 远端地址使用了明文 http。
    case insecureRemoteEndpoint(String)
    /// 地址指向私网 / 链路本地网段。
    case privateNetworkAddress(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The endpoint is not a valid URL."
        case .unsupportedScheme(let scheme):
            return "The endpoint scheme '\(scheme)' is not supported. Use http or https."
        case .insecureRemoteEndpoint(let host):
            return "The endpoint '\(host)' must use https."
        case .privateNetworkAddress(let host):
            return "The endpoint '\(host)' points to a private or local network address."
        }
    }
}
