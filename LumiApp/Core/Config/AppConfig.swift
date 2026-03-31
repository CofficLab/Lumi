import Foundation
import SwiftData
import SwiftUI

/// 应用配置管理器，负责应用级设置和通用配置
enum AppConfig {
    
    // MARK: - Layout Constants
    
    /// 统一的头部高度（侧边栏顶部和详情栏头部）
    static let headerHeight: CGFloat = 44
    
    // MARK: - Database Container (通过 DBConfig)
    
    /// 获取配置好的 SwiftData 模型容器
    ///
    /// 此方法为 `DBConfig.getContainer()` 的便捷访问点。
    ///
    /// - Returns: 配置完整的 ModelContainer 实例
    static func getContainer() -> ModelContainer {
        DBConfig.getContainer()
    }

    // MARK: - Directory Helpers

    /// 获取数据库文件夹目录（应用主库与插件子目录的根目录）
    ///
    /// 此方法为 `DBConfig.getDBFolderURL()` 的便捷访问点。
    ///
    /// - Returns: 数据库目录的 URL
    static func getDBFolderURL() -> URL {
        DBConfig.getDBFolderURL()
    }
    
    /// 获取指定插件的数据库/存储目录
    ///
    /// 此方法为 `DBConfig.getPluginDBFolderURL(pluginName:)` 的便捷访问点。
    ///
    /// - Parameter pluginName: 插件名称
    /// - Returns: 该插件的存储目录 URL
    static func getPluginDBFolderURL(pluginName: String) -> URL {
        DBConfig.getPluginDBFolderURL(pluginName: pluginName)
    }
    
    /// Core 数据目录
    ///
    /// 此方法为 `DBConfig.getCoreDBFolderURL()` 的便捷访问点。
    ///
    /// - Returns: Core 数据目录的 URL
    static func getCoreDBFolderURL() -> URL {
        DBConfig.getCoreDBFolderURL()
    }

    /// 获取当前应用的 App Support 目录
    ///
    /// 路径格式：`~/Library/Application Support/com.cofficlab.Lumi`
    ///
    /// - Returns: App Support 目录的 URL
    static func getCurrentAppSupportDir() -> URL {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("无法获取 App Support 目录")
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.cofficlab.Lumi"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)

        // 确保目录存在
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        return appDirectory
    }

    /// 获取本地容器目录
    ///
    /// 用于 App Groups 共享数据。
    ///
    /// - Returns: 容器目录的 URL，如果不存在则返回 nil
    static var localContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.bundleIdentifier ?? "")
    }

    /// 获取文档目录
    ///
    /// - Returns: 文档目录的 URL，如果不存在则返回 nil
    static var localDocumentsDir: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
