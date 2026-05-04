import Foundation

/// Build Server 配置存储
///
/// 管理多个项目的 `buildServer.json` 文件。
/// 存储位置：`AppConfig.getDBFolderURL()/EditorXcodePlugin/<projectHash>/buildServer.json`
///
/// 每个项目通过其 workspace 路径的 MD5 哈希来区分，确保不同项目的配置互不干扰。
final class XcodeBuildServerStore: @unchecked Sendable {

    // MARK: - Constants

    private static let pluginDirName = "EditorXcodePlugin"
    private static let fileName = "buildServer.json"
    private static let serverName = "xcode build server"

    // MARK: - Project Directory

    /// 插件存储根目录
    private static var rootDirectoryURL: URL {
        AppConfig.getDBFolderURL()
            .appendingPathComponent(pluginDirName, isDirectory: true)
    }

    /// 根据项目路径生成专属目录
    ///
    /// 使用 workspace 路径的 MD5 哈希作为子目录名，避免路径特殊字符问题。
    ///
    /// - Parameter workspacePath: Xcode workspace 的绝对路径
    /// - Returns: 该项目的存储目录 URL
    private static func directoryURL(forWorkspace workspacePath: String) -> URL {
        let projectHash = workspacePath.md5Hash
        return rootDirectoryURL
            .appendingPathComponent(projectHash, isDirectory: true)
    }

    /// 获取指定项目的 buildServer.json 文件路径
    ///
    /// - Parameter workspacePath: Xcode workspace 的绝对路径
    /// - Returns: buildServer.json 的完整路径 URL
    private static func fileURL(forWorkspace workspacePath: String) -> URL {
        directoryURL(forWorkspace: workspacePath)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    // MARK: - Read

    /// 读取并解析指定项目的 buildServer.json
    ///
    /// - Parameter workspacePath: Xcode workspace 的绝对路径
    /// - Returns: 解析后的配置，文件不存在或解析失败返回 nil
    static func load(forWorkspace workspacePath: String) -> Config? {
        let url = fileURL(forWorkspace: workspacePath)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let storedWorkspacePath = json["workspace"] as? String ?? ""
        let scheme = json["scheme"] as? String ?? ""

        return Config(
            buildServerJSONPath: url.path,
            workspacePath: storedWorkspacePath,
            scheme: scheme
        )
    }

    // MARK: - Write

    /// 确保指定项目的存储目录存在，并返回目录 URL
    ///
    /// `xcode-build-server config` 会将文件写到 `currentDirectoryURL`，
    /// 此方法确保目录存在并返回正确的输出目录。
    ///
    /// - Parameter workspacePath: Xcode workspace 的绝对路径
    /// - Returns: 用于 `xcode-build-server config` 的 `currentDirectoryURL`
    @discardableResult
    static func ensureDirectory(forWorkspace workspacePath: String) -> URL {
        let dir = directoryURL(forWorkspace: workspacePath)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    // MARK: - Validate

    /// 校验已有的 buildServer.json 是否与指定 workspace 匹配
    ///
    /// - Parameter workspacePath: Xcode workspace 的绝对路径
    /// - Returns: 匹配且有效则返回 Config，否则返回 nil
    static func validate(forWorkspace workspacePath: String) -> Config? {
        guard let config = load(forWorkspace: workspacePath),
              !config.scheme.isEmpty,
              config.workspacePath == workspacePath else {
            return nil
        }
        return config
    }

    // MARK: - Cleanup

    /// 清理指定项目的 buildServer.json
    ///
    /// - Parameter workspacePath: Xcode workspace 的绝对路径
    static func remove(forWorkspace workspacePath: String) {
        let dir = directoryURL(forWorkspace: workspacePath)
        try? FileManager.default.removeItem(at: dir)
    }

    /// 清理所有项目的 buildServer.json
    static func removeAll() {
        try? FileManager.default.removeItem(at: rootDirectoryURL)
    }

    // MARK: - Config Model

    struct Config: Equatable, Sendable {
        let buildServerJSONPath: String
        let workspacePath: String
        let scheme: String
    }
}

// MARK: - String Extension

private extension String {

    /// 计算字符串的 MD5 哈希值
    ///
    /// 用于将项目路径转换为安全的文件名。
    var md5Hash: String {
        guard let data = self.data(using: .utf8) else { return "" }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        #if canImport(CommonCrypto)
        _ = data.withUnsafeBytes { bytes in
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        #endif
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - CommonCrypto Shims

#if canImport(CommonCrypto)
import CommonCrypto
#else
// Fallback for platforms without CommonCrypto (should not happen on macOS)
let CC_MD5_DIGEST_LENGTH = 16
func CC_MD5(_ data: UnsafeRawPointer?, _ len: CC_LONG, _ md: UnsafeMutablePointer<UInt8>?) -> UnsafeMutablePointer<UInt8>? {
    md?.initialize(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
    return md
}
#endif
