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
    /// `file://`、`ftp://` 等没有对应仓库网页的协议一律返回 `nil`，
    /// 不能按 SCP-like 语法硬凑成 `https://file/...` 这类无关地址。
    ///
    /// - Parameter remote: 原始 remote 地址。
    /// - Returns: 可在浏览器打开的链接；无法识别或为空时返回 `nil`。
    static func webURL(fromRemote remote: String) -> URL? {
        let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let scheme = uriScheme(of: trimmed) {
            switch scheme {
            case "ssh", "git":
                return schemeWebURL(from: trimmed)
            case "http", "https":
                return webURL(strippingGitSuffix: trimmed)
            default:
                return nil
            }
        }
        // 不带 authority 的本地写法（如 `file:/tmp/repo.git`）同样没有 web 页面。
        if trimmed.lowercased().hasPrefix("file:") {
            return nil
        }
        // 其余按 scp-like 语法处理：[user@]host:path
        return scpWebURL(from: trimmed)
    }

    /// 把 remote 地址转换为 HTTPS web 链接字符串。
    static func webURLString(fromRemote remote: String) -> String? {
        webURL(fromRemote: remote)?.absoluteString
    }

    // MARK: - 私有转换

    /// 提取 `scheme://` 形式的 URI scheme。
    ///
    /// SCP-like 地址（`[user@]host:path`）冒号后直接是路径，没有 `//`，
    /// 返回 `nil` 交给 ``scpWebURL(from:)``。
    private static func uriScheme(of remote: String) -> String? {
        guard let colonIndex = remote.firstIndex(of: ":") else { return nil }
        let afterColon = remote.index(after: colonIndex)
        guard remote[afterColon...].hasPrefix("//") else { return nil }
        return remote[..<colonIndex].lowercased()
    }

    /// `scheme://[user@]host[:port]/path` → `https://host/path`。
    ///
    /// 端口一律丢弃：SSH 与 Git 协议端口（如 `:22`、`:9418`）对浏览器访问的
    /// HTTPS 页面没有意义，继承到 web 链接只会连到错误端口。
    ///
    /// 路径必须使用 `percentEncodedPath` 并按 URLComponents 重新组装：
    /// `path` 已经百分号解码，`%23` 会变成真正的 `#`，再当作文本重新解析时
    /// 就变成 fragment 分隔符，截断仓库路径（issue #1095）。
    private static func schemeWebURL(from remote: String) -> URL? {
        guard let components = URLComponents(string: remote),
              let host = components.host,
              !host.isEmpty else {
            return nil
        }
        var path = components.percentEncodedPath
        while path.hasPrefix("/") { path.removeFirst() }
        while path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix(".git") {
            path.removeLast(4)
        }

        var target = URLComponents()
        target.scheme = "https"
        target.host = host
        target.percentEncodedPath = path.isEmpty ? "" : "/\(path)"
        guard let url = target.url,
              url.scheme?.lowercased() == "https",
              let targetHost = url.host,
              !targetHost.isEmpty else {
            return nil
        }
        return url
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
