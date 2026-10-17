import Foundation

/// PluginMail 运行时路径。
///
/// - Important: `fallbackDataDirectory()` **只在 `StorageProviding` 未注册时**使用
///   （例如独立宿主或测试）。正常运行时插件目录一律由
///   `StorageProviding.pluginDataDirectory(for:)` 提供，
///   这样数据跟随应用的数据版本根目录（`db_debug_v6` / `db_production_v6`），
///   而不会脱离版本化路径。
public enum MailPluginRuntime {
    public static let pluginID = "com.coffic.lumi.plugin.mail"

    /// `StorageProviding` 缺失时的兜底目录。
    ///
    /// - Note: 保留这个兜底是因为 `MailPlugin` 可能被非标准宿主装配；
    ///   正常 App 启动路径不会走到这里。
    public static func fallbackDataDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(pluginID, isDirectory: true)
    }
}
