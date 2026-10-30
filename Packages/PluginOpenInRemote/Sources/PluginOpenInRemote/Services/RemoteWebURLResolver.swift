import Foundation

/// 把 Git remote 地址转换为浏览器可访问的 HTTPS web 链接。
///
/// Git 的 remote 地址有多种写法，但它们最终都指向同一个 Web 页面：
///
/// | remote 写法 | web 链接 |
/// |---|---|
/// | `git@github.com:user/repo.git` | `https://github.com/user/repo` |
/// | `ssh://git@github.com/user/repo.git` | `https://github.com/user/repo` |
/// | `https://github.com/user/repo.git` | `https://github.com/user/repo` |
/// | `git://github.com/user/repo.git` | `https://github.com/user/repo` |
///
/// 转换规则保持**纯函数**、无副作用，便于单元测试逐条锁定。
enum RemoteWebURLResolver {
    /// 把 remote 地址转换为 HTTPS web 链接。
    ///
    /// - Parameter remote: 原始 remote 地址。
    /// - Returns: 可在浏览器打开的链接；无法识别或为空时返回 `nil`。
    static func webURL(fromRemote remote: String) -> URL? {
        let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("ssh://") {
            return sshWebURL(from: trimmed)
        }
        if lowercased.hasPrefix("git://") {
            return hostPathWebURL(String(trimmed.dropFirst("git://".count)))
        }
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            return webURL(strippingGitSuffix: trimmed)
        }
        // 其余按 scp-like 语法处理：[user@]host:path
        return scpWebURL(from: trimmed)
    }

    /// 把 remote 地址转换为 HTTPS web 链接字符串。
    static func webURLString(fromRemote remote: String) -> String? {
        webURL(fromRemote: remote)?.absoluteString
    }

    // MARK: - 私有转换

    /// `ssh://[user@]host[:port]/path` → `https://host/path`。
    ///
    /// 端口被丢弃：Web 页面走 HTTPS 的标准端口，SSH 端口对浏览器无意义。
    private static func sshWebURL(from remote: String) -> URL? {
        guard let components = URLComponents(string: remote),
              let host = components.host,
              !host.isEmpty else {
            return nil
        }
        var path = components.path
        while path.hasPrefix("/") { path.removeFirst() }
        let suffix = path.isEmpty ? "" : "/\(path)"
        return hostPathWebURL("\(host)\(suffix)")
    }

    /// scp-like 语法 `[user@]host:path` → `https://host/path`。
    private static func scpWebURL(from remote: String) -> URL? {
        guard let colonIndex = remote.firstIndex(of: ":") else { return nil }

        let authority = String(remote[..<colonIndex])
        var path = String(remote[remote.index(after: colonIndex)...])

        // authority 形如 `git@github.com` 或 `github.com`。
        let host: String
        if let atIndex = authority.lastIndex(of: "@") {
            host = String(authority[authority.index(after: atIndex)...])
        } else {
            host = authority
        }
        guard !host.isEmpty else { return nil }

        // 路径可能以 `/` 开头（`git@host:/abs/path`），Web 链接不需要前导斜杠。
        while path.hasPrefix("/") { path.removeFirst() }
        guard !path.isEmpty else { return nil }

        return hostPathWebURL("\(host)/\(path)")
    }

    /// `host/path` → `https://host/path`。
    private static func hostPathWebURL(_ hostPath: String) -> URL? {
        webURL(strippingGitSuffix: hostPath)
    }

    /// 拼装 `https://` 前缀并去掉 `.git` 后缀。
    private static func webURL(strippingGitSuffix value: String) -> URL? {
        var path = value
        while path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix(".git") {
            path = String(path.dropLast(4))
        }
        guard !path.isEmpty else { return nil }

        let candidate = path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://")
            ? path
            : "https://\(path)"

        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return url
    }
}
