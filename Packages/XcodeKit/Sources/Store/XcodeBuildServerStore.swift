import Foundation
import CommonCrypto
import os

/// Build Server 配置存储
///
/// 管理多个项目的 `buildServer.json` 文件。
/// 存储位置为插件专属目录（`AppConfig.getPluginDBFolderURL(pluginName:)`），
/// 每个项目通过其 workspace 路径的 MD5 哈希分子目录区分。
public final class XcodeBuildServerStore: @unchecked Sendable {

    // MARK: - Constants

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.build-server-store")

    private let fileName = "buildServer.json"
    private let corruptFileName = "buildServer.corrupt.json"

    /// 插件专属存储目录（由插件注入，遵循 plugin-storage-rules）
    public let pluginDirectoryURL: URL

    // MARK: - Init

    public init(pluginDirectoryURL: URL) {
        self.pluginDirectoryURL = pluginDirectoryURL
    }

    /// 兼容旧调用方；`storageRootURL` 应传入插件目录而非 Application Support 根目录。
    @available(*, deprecated, renamed: "init(pluginDirectoryURL:)")
    public init(storageRootURL: URL) {
        self.pluginDirectoryURL = storageRootURL
    }

    // MARK: - Project Directory

    /// 根据项目路径生成专属目录
    private func directoryURL(forWorkspace workspacePath: String) -> URL {
        let projectHash = workspacePath.md5Hash
        return pluginDirectoryURL
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
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let json: [String: Any]
        do {
            let data = try Data(contentsOf: url)
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Self.logger.error("Load buildServer.json failed: root JSON is not an object")
                quarantineCorruptFile(at: url, forWorkspace: workspacePath)
                return nil
            }
            json = parsed
        } catch {
            Self.logger.error("Load buildServer.json failed: \(error.localizedDescription)")
            quarantineCorruptFile(at: url, forWorkspace: workspacePath)
            return nil
        }

        let storedWorkspacePath = json["workspace"] as? String ?? ""
        let scheme = json["scheme"] as? String ?? ""
        let buildRoot = json["build_root"] as? String

        return Config(
            buildServerJSONPath: url.path,
            workspacePath: storedWorkspacePath,
            scheme: scheme,
            buildRoot: buildRoot
        )
    }

    /// Reads build server metadata used for semantic indexing.
    public func loadMetadata(forWorkspace workspacePath: String) -> Metadata? {
        let url = fileURL(forWorkspace: workspacePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let storedWorkspacePath = json["workspace"] as? String ?? ""
        let scheme = json["scheme"] as? String ?? ""
        let buildRoot = json["build_root"] as? String
        let storeDirectory = directoryURL(forWorkspace: workspacePath)

        return Metadata(
            buildServerJSONPath: url.path,
            workspacePath: storedWorkspacePath,
            scheme: scheme,
            buildRoot: buildRoot,
            storeDirectory: storeDirectory,
            compileDatabasePath: storeDirectory.appendingPathComponent(".compile", isDirectory: false).path
        )
    }

    public func compileDatabaseURL(forWorkspace workspacePath: String) -> URL {
        directoryURL(forWorkspace: workspacePath)
            .appendingPathComponent(".compile", isDirectory: false)
    }

    /// Plugin-local DerivedData root for a workspace (`<hash>/DerivedData/`).
    public func derivedDataDirectory(forWorkspace workspacePath: String) -> URL {
        directoryURL(forWorkspace: workspacePath)
            .appendingPathComponent("DerivedData", isDirectory: true)
    }

    /// Whether `build_root` lives under this workspace's plugin-local DerivedData.
    public func isManagedBuildRoot(_ buildRoot: String?, forWorkspace workspacePath: String) -> Bool {
        guard let buildRoot = buildRoot?.trimmingCharacters(in: .whitespacesAndNewlines),
              !buildRoot.isEmpty else {
            return false
        }

        let managedPrefix = derivedDataDirectory(forWorkspace: workspacePath).standardizedFileURL.path
        let normalizedBuildRoot = URL(fileURLWithPath: buildRoot).standardizedFileURL.path
        return normalizedBuildRoot == managedPrefix || normalizedBuildRoot.hasPrefix(managedPrefix + "/")
    }

    // MARK: - Write

    /// 确保指定项目的存储目录存在，并返回目录 URL
    ///
    /// `xcode-build-server config` 会将文件写到 `currentDirectoryURL`，
    /// 此方法确保目录存在并返回正确的输出目录。
    @discardableResult
    public func ensureDirectory(forWorkspace workspacePath: String) -> URL {
        let dir = directoryURL(forWorkspace: workspacePath)
        do {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        } catch {
            Self.logger.error("Create build server store directory failed: \(error.localizedDescription)")
        }
        return dir
    }

    /// Updates `build_root` in an existing buildServer.json after a plugin-local build.
    ///
    /// Skips the write when `build_root` is already up to date. Rewriting the file would bump its
    /// modification date past the freshly generated `.compile`, making the freshness check
    /// (`isCompileDatabaseFresh`) treat the compile database as stale on the next launch and trigger
    /// an endless re-index loop.
    @discardableResult
    public func updateBuildRoot(forWorkspace workspacePath: String, buildRoot: String) -> Bool {
        let url = fileURL(forWorkspace: workspacePath)
        guard FileManager.default.fileExists(atPath: url.path),
              var json = (try? Data(contentsOf: url)).flatMap({
                  try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
              }) else {
            return false
        }

        if let existingBuildRoot = json["build_root"] as? String,
           Self.normalizedPath(existingBuildRoot) == Self.normalizedPath(buildRoot) {
            return true
        }

        json["build_root"] = buildRoot
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            return false
        }

        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            Self.logger.error("Update build_root failed: \(error.localizedDescription)")
            return false
        }
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
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            Self.logger.error("Remove build server store failed: \(error.localizedDescription)")
        }
    }

    /// 清理所有项目的 buildServer.json
    public func removeAll() {
        do {
            try FileManager.default.removeItem(at: pluginDirectoryURL)
        } catch {
            Self.logger.error("Remove all build server stores failed: \(error.localizedDescription)")
        }
    }

    static func normalizedPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: trimmed).standardizedFileURL.path
    }

    private func corruptFileURL(forWorkspace workspacePath: String) -> URL {
        directoryURL(forWorkspace: workspacePath)
            .appendingPathComponent(corruptFileName, isDirectory: false)
    }

    private func quarantineCorruptFile(at fileURL: URL, forWorkspace workspacePath: String) {
        let quarantineURL = corruptFileURL(forWorkspace: workspacePath)
        do {
            if FileManager.default.fileExists(atPath: quarantineURL.path) {
                try FileManager.default.removeItem(at: quarantineURL)
            }
            try FileManager.default.moveItem(at: fileURL, to: quarantineURL)
        } catch {
            Self.logger.error("Quarantine corrupt buildServer.json failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Config Model

    public struct Config: Equatable, Sendable {
        public let buildServerJSONPath: String
        public let workspacePath: String
        public let scheme: String
        public let buildRoot: String?

        public init(
            buildServerJSONPath: String,
            workspacePath: String,
            scheme: String,
            buildRoot: String? = nil
        ) {
            self.buildServerJSONPath = buildServerJSONPath
            self.workspacePath = workspacePath
            self.scheme = scheme
            self.buildRoot = buildRoot
        }
    }

    public struct Metadata: Equatable, Sendable {
        public let buildServerJSONPath: String
        public let workspacePath: String
        public let scheme: String
        public let buildRoot: String?
        public let storeDirectory: URL
        public let compileDatabasePath: String

        public init(
            buildServerJSONPath: String,
            workspacePath: String,
            scheme: String,
            buildRoot: String?,
            storeDirectory: URL,
            compileDatabasePath: String
        ) {
            self.buildServerJSONPath = buildServerJSONPath
            self.workspacePath = workspacePath
            self.scheme = scheme
            self.buildRoot = buildRoot
            self.storeDirectory = storeDirectory
            self.compileDatabasePath = compileDatabasePath
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
