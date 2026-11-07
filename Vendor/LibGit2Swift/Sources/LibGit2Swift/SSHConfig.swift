import Foundation
import OSLog

// MARK: - SSH Configuration Parser

/// SSH 配置解析器与远程 URL 规范化工具。
///
/// 解析 `~/.ssh/config`（支持 `Include`、`Host` 多模式、`*`/`?` 通配符），
/// 并把 scp 风格（`git@host:path`）或 `ssh://` 形式的远程 URL 重写为携带
/// 实际端口 / 主机 / 用户的地址。
///
/// 背景：libgit2 的 SSH 传输层基于 libssh2，**不会读取 `~/.ssh/config`**。
/// 当 SSH 服务跑在非 22 端口（例如 `Port 2014`）时，libssh2 仍会连接默认的
/// 22 端口；若 22 端口被防火墙静默丢弃，TCP 能建立但收不到 banner，
/// 表现为 `failed to start SSH session: Failed getting banner`。
/// 因此在建立连接前用本工具把 URL 规范化，等价于让 libgit2 也尊重 ssh config。
public struct SSHConfig {

    /// SSH 主机配置
    public struct HostConfig {
        public let host: String
        public let hostName: String?
        public let port: Int?
        public let user: String?
        public let identityFile: String?
        public let preferredAuthentications: String?

        public init(
            host: String,
            hostName: String? = nil,
            port: Int? = nil,
            user: String? = nil,
            identityFile: String? = nil,
            preferredAuthentications: String? = nil
        ) {
            self.host = host
            self.hostName = hostName
            self.port = port
            self.user = user
            self.identityFile = identityFile
            self.preferredAuthentications = preferredAuthentications
        }

        /// 依据该主机配置重写原始 URL（包含配置端口与 HostName 覆盖）。
        public func getFullSSHURL(originalURL: String) -> String {
            return SSHConfig.normalizedURL(for: originalURL, config: self) ?? originalURL
        }
    }

    /// 从 ~/.ssh/config 读取并解析 SSH 配置
    /// - Returns: 主机配置数组（`Host a b` 会展开为多个条目）
    public static func parseSSHConfig() -> [HostConfig] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let configPath = "\(homeDir)/.ssh/config"

        guard FileManager.default.fileExists(atPath: configPath) else {
            os_log("⚠️ SSH config file not found at: \(configPath)")
            return []
        }

        do {
            let content = try String(contentsOfFile: configPath, encoding: .utf8)
            var visited: Set<String> = []
            return parseConfig(content: content, baseDirectory: URL(fileURLWithPath: "\(homeDir)/.ssh"), visited: &visited)
        } catch {
            os_log("⚠️ Failed to read SSH config: \(error)")
            return []
        }
    }

    /// 查找匹配特定主机的配置（OpenSSH 语义：按文件顺序取第一个匹配，含通配符）
    /// - Parameter hostname: 主机名（例如 codebowl.juhe.cn）
    /// - Returns: 匹配的配置，如果没有找到返回 nil
    public static func findConfig(for hostname: String) -> HostConfig? {
        let configs = parseSSHConfig()
        return configs.first { hostMatches(pattern: $0.host, hostname: hostname) }
    }

    /// 判断主机是否匹配 `Host` 模式（`*` / `?` 通配符，忽略大小写）
    public static func hostMatches(pattern: String, hostname: String) -> Bool {
        let pattern = pattern.lowercased()
        let hostname = hostname.lowercased()

        if pattern == hostname { return true }
        if pattern == "*" { return true }
        if !pattern.contains("*") && !pattern.contains("?") { return false }

        var regex = "^"
        for character in pattern {
            switch character {
            case "*":
                regex += ".*"
            case "?":
                regex += "."
            case ".", "\\", "(", ")", "[", "]", "{", "}", "^", "$", "|", "+":
                regex += "\\\(character)"
            default:
                regex.append(character)
            }
        }
        regex += "$"

        guard let expression = try? NSRegularExpression(pattern: regex) else { return false }
        let range = NSRange(hostname.startIndex..., in: hostname)
        return expression.firstMatch(in: hostname, range: range) != nil
    }

    // MARK: - URL 规范化

    /// 依据 `~/.ssh/config` 重写 SSH 远程 URL，使 libssh2 使用正确的端口 / 主机 / 用户。
    /// - Parameter originalURL: 远程 URL（`git@host:path`、`ssh://user@host:port/path` 等）
    /// - Returns: 重写后的 URL；无需变化时返回 `nil`
    public static func normalizedURL(for originalURL: String) -> String? {
        let trimmed = originalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let parsed = parseRemoteURL(trimmed) else { return nil }
        guard let config = findConfig(for: parsed.host) else { return nil }
        return normalizedURL(for: parsed, config: config)
    }

    /// 供测试与内部使用的规范化入口：使用给定的配置列表而不是读取真实文件。
    static func normalizedURL(for originalURL: String, configs: [HostConfig]) -> String? {
        let trimmed = originalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = parseRemoteURL(trimmed) else { return nil }
        guard let config = configs.first(where: { hostMatches(pattern: $0.host, hostname: parsed.host) }) else {
            return nil
        }
        return normalizedURL(for: parsed, config: config)
    }

    /// 直接应用单个主机配置到原始 URL（`HostConfig.getFullSSHURL` 使用）。
    static func normalizedURL(for originalURL: String, config: HostConfig) -> String? {
        let trimmed = originalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = parseRemoteURL(trimmed) else { return nil }
        return normalizedURL(for: parsed, config: config)
    }

    /// 应用单个主机配置到已解析的 URL，返回规范化结果（无变化时返回 nil）。
    static func normalizedURL(for parsed: ParsedRemoteURL, config: HostConfig) -> String? {
        let effectiveHost = config.hostName ?? parsed.host
        let effectivePort = config.port ?? parsed.port ?? 22
        let effectiveUser = parsed.user ?? config.user

        let hostChanged = config.hostName != nil && config.hostName != parsed.host
        let portChanged = config.port != nil && (parsed.port ?? 22) != config.port
        let userChanged = parsed.user == nil && config.user != nil

        guard hostChanged || portChanged || userChanged else { return nil }

        let path = parsed.path.hasPrefix("/") ? parsed.path : "/\(parsed.path)"
        var url = "ssh://"
        if let user = effectiveUser {
            url += user + "@"
        }
        url += effectiveHost + ":\(effectivePort)" + path
        return url
    }

    /// 解析后的远程 URL
    struct ParsedRemoteURL {
        let scheme: String?   // nil 表示 scp 风格
        let user: String?
        let host: String
        let port: Int?
        let path: String
    }

    /// 解析 scp 风格（`[user@]host:path`）或 `ssh://` 形式的远程 URL。
    /// 非 SSH 协议（http/https 等）返回 nil。
    static func parseRemoteURL(_ url: String) -> ParsedRemoteURL? {
        if url.contains("://") {
            guard url.hasPrefix("ssh://"),
                  let components = URLComponents(string: url),
                  let host = components.host else {
                return nil
            }
            return ParsedRemoteURL(
                scheme: components.scheme,
                user: components.user,
                host: host,
                port: components.port,
                path: components.path
            )
        }

        // scp 风格：[user@]host:path（host 不含 / 与 :，排除 Windows 盘符与本地路径）
        let pattern = "^(?:([^@]+)@)?([^:/]+):(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) else {
            return nil
        }

        let user = match.range(at: 1).location != NSNotFound ? String(url[Range(match.range(at: 1), in: url)!]) : nil
        let host = String(url[Range(match.range(at: 2), in: url)!])
        let path = String(url[Range(match.range(at: 3), in: url)!])

        guard !host.isEmpty, !path.isEmpty else { return nil }
        return ParsedRemoteURL(scheme: nil, user: user, host: host, port: nil, path: path)
    }

    // MARK: - 配置解析

    /// 解析 SSH 配置文件内容
    /// - Parameters:
    ///   - content: 配置文本
    ///   - baseDirectory: `Include` 相对路径的基准目录（默认 ~/.ssh）
    ///   - visited: 已访问文件路径集合（防止 Include 循环）
    static func parseConfig(
        content: String,
        baseDirectory: URL? = nil,
        visited: inout Set<String>
    ) -> [HostConfig] {
        var configs: [HostConfig] = []
        var currentPatterns: [String] = []
        var currentHostName: String?
        var currentPort: Int?
        var currentUser: String?
        var currentIdentityFile: String?
        var currentPreferredAuthentications: String?

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        func flushBlock() {
            guard !currentPatterns.isEmpty else { return }
            for pattern in currentPatterns {
                configs.append(HostConfig(
                    host: pattern,
                    hostName: currentHostName,
                    port: currentPort,
                    user: currentUser,
                    identityFile: currentIdentityFile,
                    preferredAuthentications: currentPreferredAuthentications
                ))
            }
        }

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // 跳过空行和注释
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }

            let parts = trimmedLine.split(separator: " ", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard let key = parts.first?.lowercased(), parts.count >= 2 else { continue }
            let value = parts[1]

            switch key {
            case "host":
                flushBlock()
                currentPatterns = value.split(separator: " ").map(String.init)
                currentHostName = nil
                currentPort = nil
                currentUser = nil
                currentIdentityFile = nil
                currentPreferredAuthentications = nil

            case "include":
                // 递归读取 Include 的文件（支持 ~ 展开与相对路径）
                var includePath = value
                if includePath.hasPrefix("~") {
                    includePath = includePath.replacingOccurrences(of: "~", with: homeDir)
                } else if !includePath.hasPrefix("/"), let baseDirectory {
                    includePath = baseDirectory.appendingPathComponent(includePath).path
                }
                // 支持通配符 Include（如 Include config.d/*）
                if includePath.contains("*") || includePath.contains("?") {
                    let directory = (includePath as NSString).deletingLastPathComponent
                    let pattern = (includePath as NSString).lastPathComponent
                    if let files = try? FileManager.default.contentsOfDirectory(atPath: directory) {
                        for file in files.sorted() where SSHConfig.fileName(file, matches: pattern) {
                            let fullPath = "\(directory)/\(file)"
                            appendIncludedConfig(fullPath, configs: &configs, visited: &visited)
                        }
                    }
                } else if FileManager.default.fileExists(atPath: includePath) {
                    appendIncludedConfig(includePath, configs: &configs, visited: &visited)
                }

            case "hostname":
                currentHostName = value
            case "port":
                currentPort = Int(value)
            case "user":
                currentUser = value
            case "identityfile":
                // 展开 ~ 为完整路径
                if value.hasPrefix("~") {
                    currentIdentityFile = value.replacingOccurrences(of: "~", with: homeDir)
                } else {
                    currentIdentityFile = value
                }
            case "preferredauthentications":
                currentPreferredAuthentications = value
            default:
                break
            }
        }

        // 保存最后一个配置
        flushBlock()

        return configs
    }

    /// 递归读取被 Include 的文件并把配置并入结果
    private static func appendIncludedConfig(
        _ filePath: String,
        configs: inout [HostConfig],
        visited: inout Set<String>
    ) {
        let resolvedPath = (filePath as NSString).standardizingPath
        guard !visited.contains(resolvedPath),
              let content = try? String(contentsOfFile: resolvedPath, encoding: .utf8) else {
            return
        }
        visited.insert(resolvedPath)
        let base = URL(fileURLWithPath: resolvedPath).deletingLastPathComponent()
        configs.append(contentsOf: parseConfig(content: content, baseDirectory: base, visited: &visited))
    }

    /// 文件名是否匹配 Include 通配符（支持 * 与 ?）
    private static func fileName(_ name: String, matches pattern: String) -> Bool {
        guard pattern.contains("*") || pattern.contains("?") else { return name == pattern }
        var regex = "^"
        for character in pattern {
            switch character {
            case "*": regex += ".*"
            case "?": regex += "."
            default: regex.append(character)
            }
        }
        regex += "$"
        guard let expression = try? NSRegularExpression(pattern: regex) else { return false }
        return expression.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil
    }
}
