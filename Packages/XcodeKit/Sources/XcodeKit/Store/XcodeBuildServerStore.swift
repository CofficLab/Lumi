import Foundation
import CommonCrypto

/// Build Server 配置存储
///
/// 管理多个项目的 `buildServer.json` 文件。
/// 存储位置由 `storageRootURL` 决定，每个项目通过其 workspace 路径的 MD5 哈希来区分。
public final class XcodeBuildServerStore: @unchecked Sendable {

    // MARK: - Constants

    private let pluginDirName = "EditorXcodePlugin"
    private let fileName = "buildServer.json"

    /// 存储根路径（由外部注入）
    public let storageRootURL: URL

    // MARK: - Init

    public init(storageRootURL: URL) {
        self.storageRootURL = storageRootURL
    }

    // MARK: - Project Directory

    /// 插件存储根目录
    private var rootDirectoryURL: URL {
        storageRootURL.appendingPathComponent(pluginDirName, isDirectory: true)
    }

    /// 根据项目路径生成专属目录
    private func directoryURL(forWorkspace workspacePath: String) -> URL {
        let projectHash = workspacePath.md5Hash
        return rootDirectoryURL
            .appendingPathComponent(projectHash, isDirectory: true)
    }

    /// 获取指定项目的 buildServer.json 文件路径
    private func fileURL(forWorkspace workspacePath: String) -> URL {
        directoryURL(forWorkspace: workspacePath)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    // MARK: - Read

    /// 读取并解析指定项目的 buildServer.json
    public func load(forWorkspace workspacePath: String) -> Config? {
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
    @discardableResult
    public func ensureDirectory(forWorkspace workspacePath: String) -> URL {
        let dir = directoryURL(forWorkspace: workspacePath)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    // MARK: - Validate

    /// 校验已有的 buildServer.json 是否与指定 workspace 匹配
    public func validate(forWorkspace workspacePath: String) -> Config? {
        guard let config = load(forWorkspace: workspacePath),
              !config.scheme.isEmpty,
              config.workspacePath == workspacePath else {
            return nil
        }
        return config
    }

    // MARK: - Cleanup

    /// 清理指定项目的 buildServer.json
    public func remove(forWorkspace workspacePath: String) {
        let dir = directoryURL(forWorkspace: workspacePath)
        try? FileManager.default.removeItem(at: dir)
    }

    /// 清理所有项目的 buildServer.json
    public func removeAll() {
        try? FileManager.default.removeItem(at: rootDirectoryURL)
    }

    // MARK: - Config Model

    public struct Config: Equatable, Sendable {
        public let buildServerJSONPath: String
        public let workspacePath: String
        public let scheme: String

        public init(buildServerJSONPath: String, workspacePath: String, scheme: String) {
            self.buildServerJSONPath = buildServerJSONPath
            self.workspacePath = workspacePath
            self.scheme = scheme
        }
    }
}

// MARK: - String Extension

extension String {

    /// 计算字符串的 MD5 哈希值
    var md5Hash: String {
        guard let data = self.data(using: .utf8) else { return "" }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = data.withUnsafeBytes { bytes in
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
