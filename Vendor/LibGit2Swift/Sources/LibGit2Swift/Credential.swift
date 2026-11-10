import Foundation
import Clibgit2
import OSLog
import MagicLog
import Security

// MARK: - Credential Manager

/// 管理Git凭据的辅助类
public class CredentialManager: SuperLog {
    public static let emoji = "🔑"

    /// 控制凭据回调函数的日志输出
    public static var verboseCredentialCallback: Bool = true

    /// 从 macOS Keychain 获取指定URL的Git凭据
    /// - Parameter urlString: Git远程URL
    /// - Returns: 用户名和密码元组，如果未找到则返回nil
    public static func getCredentialFromKeychain(for urlString: String, verbose: Bool = true) -> (username: String, password: String)? {
        // 检查 urlString 是否有效
        guard !urlString.isEmpty else {
            if verbose { os_log("\(t) URL string is empty in getCredentialFromKeychain") }
            return nil
        }


        // 从URL中提取host
        guard let url = URL(string: urlString) else {
            if verbose { os_log("\(t) Invalid URL: \(urlString)") }
            return nil
        }

        let host = url.host ?? urlString
        let `protocol` = url.scheme ?? "https"

        if verbose { os_log("\(t)Looking up credentials for host: \(host)") }

        // 首先尝试精确匹配（包含 protocol）
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrProtocol as String: `protocol`,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &result)

        // 如果精确匹配失败，尝试只匹配 server（不指定 protocol）
        if status != errSecSuccess {
            if verbose { os_log("\(t)Exact match failed (status: \(status)), trying without protocol filter") }
            query.removeValue(forKey: kSecAttrProtocol as String)
            status = SecItemCopyMatching(query as CFDictionary, &result)
        }

        guard status == errSecSuccess else {
            if verbose { os_log("\(t) SecItemCopyMatching failed with status: \(status)") }
            return nil
        }

        guard let item = result as? [String: Any] else {
            if verbose { os_log("\(t) Failed to cast result to dictionary") }
            return nil
        }

        guard let username = item[kSecAttrAccount as String] as? String else {
            if verbose { os_log("\(t) No username found in Keychain item") }
            return nil
        }

        guard let passwordData = item[kSecValueData as String] as? Data else {
            if verbose { os_log("\(t) No password data found in Keychain item") }
            return nil
        }

        guard let password = String(data: passwordData, encoding: .utf8) else {
            if verbose { os_log("\(t) Failed to convert password data to string") }
            return nil
        }

        if verbose { os_log("\(t)Found credentials in Keychain for user: \(username)") }
        return (username, password)
    }

    /// 尝试从git-credential-*获取凭据（作为fallback）
    /// - Parameter urlString: Git远程URL
    /// - Returns: 用户名和密码元组，如果未找到则返回nil
    public static func getCredentialFromGitHelper(for urlString: String, verbose: Bool = true) -> (username: String, password: String)? {
        // 实现git credential fill协议
        // 这是一个fallback方案，如果Keychain中没有找到凭据

        if verbose { os_log("\(t) Attempting to use git credential helper for: \(urlString)") }

        // TODO: 实现与git credential helper的通信
        // 这需要通过Process调用git credential fill

        return nil
    }

    /// 为指定的URL获取凭据
    /// - Parameter urlString: Git远程URL
    /// - Returns: 用户名和密码元组，如果未找到则返回nil
    public static func getCredential(for urlString: String, verbose: Bool = true) -> (username: String, password: String)? {
        // 首先尝试从Keychain获取
        if let credential = getCredentialFromKeychain(for: urlString, verbose: verbose) {
            return credential
        }

        // Fallback到git credential helper
        return getCredentialFromGitHelper(for: urlString, verbose: verbose)
    }

    /// 将凭据保存到Keychain
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    ///   - urlString: Git远程URL
    public static func saveCredentialToKeychain(username: String, password: String, for urlString: String, verbose: Bool = true) {
        guard let url = URL(string: urlString) else {
                if verbose { os_log("\(t) Invalid URL for saving credential: \(urlString)") }
            return
        }

        let host = url.host ?? urlString
        let `protocol` = url.scheme ?? "https"

        let passwordData = password.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrProtocol as String: `protocol`,
            kSecAttrAccount as String: username,
            kSecValueData as String: passwordData
        ]

        // 先删除旧的凭据（如果存在）
        SecItemDelete(query as CFDictionary)

        // 添加新凭据
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            if verbose { os_log("\(t) Credentials saved to Keychain for user: \(username)") }
        } else {
            if verbose { os_log("\(t) Failed to save credentials to Keychain: \(status)") }
        }
    }
}

// MARK: - Credential Callback Context

/// 用于在credential回调中传递上下文信息
private struct CredentialContext {
    let urlString: String
    var lastError: Int32 = 0
}

// MARK: - C Callback Function

/// libgit2的credential回调函数
/// 这个函数会被libgit2调用以获取认证凭据
public let gitCredentialCallback: @convention(c) (
    UnsafeMutablePointer<UnsafeMutablePointer<git_credential>?>?,
    UnsafePointer<CChar>?,
    UnsafePointer<CChar>?,
    UInt32,
    UnsafeMutableRawPointer?
) -> Int32 = { out, url, username_from_url, allowed_types, payload in
    // 检查 out 指针是否有效
    guard let outPointer = out else {
        return -1
    }

    guard let urlPointer = url else {
        return -1
    }

    // 使用更安全的方式创建字符串，限制最大长度
    let maxURLLength = 2048
    var urlBuffer = [CChar](repeating: 0, count: maxURLLength)
    strncpy(&urlBuffer, urlPointer, maxURLLength - 1)
    let urlString = String(cString: urlBuffer)

    // 检查 urlString 是否有效
    guard !urlString.isEmpty else {
        return Int32(GIT_EUSER.rawValue)
    }

    // 尝试使用文件密钥（SSH KEY 认证）
    if allowed_types & GIT_CREDENTIAL_SSH_KEY.rawValue != 0 {
        // SSH 密钥认证
        // 从 URL 中提取用户名（例如 git@github.com 中的 "git"）
        let defaultUsername = username_from_url.map { String(cString: $0) } ?? "git"

        // 尝试常见的 SSH 密钥路径
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let sshDir = homeDir + "/.ssh"
        let possibleKeys = [
            ("id_ed25519", ""),
            ("id_rsa", ""),
            ("id_ecdsa", ""),
            ("id_dsa", "")
        ]

        for (keyName, passphrase) in possibleKeys {
            let publicKeyPath = "\(sshDir)/\(keyName).pub"
            let privateKeyPath = "\(sshDir)/\(keyName)"

            // 检查私钥文件是否存在
            guard FileManager.default.fileExists(atPath: privateKeyPath) else {
                continue
            }

            // 使用默认的 SSH 密钥创建凭据
            let result = defaultUsername.withCString { usernamePtr in
                publicKeyPath.withCString { publicKeyPtr in
                    privateKeyPath.withCString { privateKeyPtr in
                        passphrase.withCString { passphrasePtr in
                            git_credential_ssh_key_new(outPointer, usernamePtr, publicKeyPtr, privateKeyPtr, passphrasePtr)
                        }
                    }
                }
            }

            if result == 0 {
                if CredentialManager.verboseCredentialCallback {
                    os_log("🔑 SSH credential created with key: \(keyName)")
                }
                return 0
            }
        }
    }

    // 根据allowed_types选择合适的凭据类型
    if allowed_types & GIT_CREDENTIAL_USERPASS_PLAINTEXT.rawValue != 0 {
        guard let (username, password) = CredentialManager.getCredential(for: urlString, verbose: CredentialManager.verboseCredentialCallback),
              !username.isEmpty,
              !password.isEmpty else {
            return Int32(GIT_EUSER.rawValue)
        }

        // 创建凭证对象
        // git_credential_userpass_plaintext_new 会使用 strdup 在内部复制字符串
        let result = username.withCString { usernamePtr in
            password.withCString { passwordPtr in
                git_credential_userpass_plaintext_new(outPointer, usernamePtr, passwordPtr)
            }
        }

        if result == 0 {
            return 0
        } else {
            return Int32(GIT_EUSER.rawValue)
        }
    }

    // 尝试 SSH 内存密钥（适用于内存中的密钥数据）
    if allowed_types & GIT_CREDENTIAL_SSH_MEMORY.rawValue != 0 {
        // 目前不支持内存中的密钥数据
        // 如果需要支持，可以在这里实现 git_credential_ssh_key_memory_new
    }

    return Int32(GIT_EUSER.rawValue)
}
