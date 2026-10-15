import Foundation

/// PluginMail 运行时路径常量。
public enum MailPluginRuntime {
    public static let pluginID = "com.coffic.lumi.plugin.mail"

    /// 插件数据目录（缓存数据库 / 附件下载落地）。
    public static func dataDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(pluginID, isDirectory: true)
    }
}
