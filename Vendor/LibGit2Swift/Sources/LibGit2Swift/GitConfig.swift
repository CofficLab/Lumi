import Foundation
import Clibgit2
import MagicLog
import OSLog

extension LibGit2 {
    public static func getGlobalConfig(key: String) throws -> String {
        return try LibGit2.serialized {
            var config: OpaquePointer?
            defer { if config != nil { git_config_free(config) } }

            guard git_config_open_default(&config) == 0, let config else {
                throw LibGit2Error.configNotFound
            }

            var outPtr: UnsafePointer<CChar>?
            let result = git_config_get_string(&outPtr, config, key)
            guard result == 0, let outPtr else {
                return ""
            }

            return String(cString: outPtr)
        }
    }

    public static func setGlobalConfig(key: String, value: String?) throws {
        try LibGit2.serialized {
            var config: OpaquePointer?
            defer { if config != nil { git_config_free(config) } }

            guard git_config_open_default(&config) == 0, let config else {
                throw LibGit2Error.configNotFound
            }

            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                let result = git_config_delete_entry(config, key)
                if result != 0 && result != GIT_ENOTFOUND.rawValue {
                    throw LibGit2Error.configKeyNotFound(key)
                }
                return
            }

            if git_config_set_string(config, key, trimmed) != 0 {
                throw LibGit2Error.configKeyNotFound(key)
            }
        }
    }
}

/// Git 配置辅助类
/// 使用 libgit2 读取 Git 配置信息
public class GitConfig: SuperLog {
    public static let emoji = "🔑"

    /// 从指定仓库路径获取用户名
    public static func getUserName(at path: String, verbose: Bool = true) throws -> String {
        if verbose { os_log("\(emoji) Getting user name at path: \(path)") }
        return try LibGit2.getConfig(key: "user.name", at: path, verbose: verbose)
    }

    /// 从指定仓库路径获取用户邮箱
    public static func getUserEmail(at path: String, verbose: Bool = true) throws -> String {
        if verbose { os_log("\(emoji) Getting user email at path: \(path)") }
        return try LibGit2.getConfig(key: "user.email", at: path, verbose: verbose)
    }
}
