import Foundation

/// 应用数据存储路径服务
///
/// 负责创建并解析 LumiApp 的数据根目录与核心数据库子目录。
/// 本实现从 `LumiApp/Services/StorageService.swift` 复刻而来，
/// 公共 API 与原文件保持完全一致（均为 `static` 调用），
/// 便于未来在不动调用方的前提下完成切换。
public final class StorageService {

    // MARK: - 初始化

    public init() {}

    // MARK: - 公开方法

    /// 创建并返回 LumiApp 的数据根目录。
    ///
    /// 路径规则：`<ApplicationSupport>/<bundleIdentifier>/db_<debug|production>_v<majorVersion>`。
    /// 当 `Bundle.main.bundleIdentifier` 缺失时回退到 `com.coffic.Lumi`。
    /// Application Support 目录不可解析时 `fatalError`，
    /// 因为这是 App 启动期不可恢复的环境错误。
    public static func makeDataRootDirectory() -> URL {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to resolve Application Support directory.")
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
        try? fileManager.createDirectory(
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
    public static func makeCoreDatabaseDirectory(in dataRootDirectory: URL) -> URL {
        let coreDirectory = dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: coreDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return coreDirectory
    }

    /// 从 `CFBundleShortVersionString` 中提取主版本号。
    ///
    /// 解析失败时返回 1，与原实现保持一致。
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