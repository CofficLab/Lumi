import Foundation

public enum AppConfig {
    public static func getDBFolderURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return appSupport.appendingPathComponent("com.coffic.Lumi", isDirectory: true)
    }

    public static func getPluginDBFolderURL(pluginName: String) -> URL {
        getDBFolderURL().appendingPathComponent(pluginName, isDirectory: true)
    }
}
