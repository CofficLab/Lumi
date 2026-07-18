import Foundation
import LumiCoreKit

/// 应用数据存储路径服务
///
/// 负责创建并解析 LumiApp 的数据根目录与核心数据库子目录。
public final class StorageService {

    public init() {}

    /// 创建并返回 LumiApp 的数据根目录。
    ///
    /// 路径规则：`<ApplicationSupport>/<bundleIdentifier>/db_<debug|production>_v<majorVersion>`。
    /// 当 `Bundle.main.bundleIdentifier` 缺失时回退到 `com.coffic.Lumi`。
    ///
    /// - Throws: `LumiBootstrapError.applicationSupportUnavailable` 当系统无法解析
    ///   Application Support 目录时；或底层 `createDirectory` 失败时（磁盘满/权限问题）。
    ///   这类错误不可恢复，由 `WindowMain` 走 `CrashedView` 呈现给用户。
    public static func makeDataRootDirectory() throws -> URL {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw LumiBootstrapError.applicationSupportUnavailable
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        let versionSuffix = "v\(majorVersion(from: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String))"

        #if DEBUG
        let databaseDirectoryName = "db_debug_\(versionSuffix)"
        #else
        let databaseDirectoryName = "db_production_\(versionSuffix)"
        #endif

        let dataRootDirectory = appDirectory.appendingPathComponent(databaseDirectoryName, isDirectory: true)
        try fileManager.createDirectory(
            at: dataRootDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return dataRootDirectory
    }

    /// 在指定数据根目录下创建 `Core` 子目录并返回其 URL。
    ///
    /// - Parameter dataRootDirectory: LumiApp 的数据根目录。
    /// - Returns: `<dataRootDirectory>/Core` 的 URL。
    /// - Throws: 底层 `createDirectory` 失败时抛错（磁盘满/权限问题）。
    public static func makeCoreDatabaseDirectory(in dataRootDirectory: URL) throws -> URL {
        let coreDirectory = dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        try FileManager.default.createDirectory(
            at: coreDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return coreDirectory
    }

    /// 从 `CFBundleShortVersionString` 中提取主版本号。
    ///
    /// - Parameter version: 完整版本号字符串，例如 `"1.2.3"`。
    /// - Returns: 主版本号；输入为 `nil`、空串或非数字前缀时回退为 `1`。
    public static func majorVersion(from version: String?) -> Int {
        guard let version,
              let major = version.split(separator: ".").first,
              let value = Int(major)
        else {
            return 1
        }

        return value
    }
}
