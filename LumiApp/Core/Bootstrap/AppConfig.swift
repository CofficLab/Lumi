import Foundation
import SwiftData
import SwiftUI

/// 应用配置管理器，负责 SwiftData 容器配置和应用级设置
enum AppConfig {
    // MARK: - Layout Constants
    
    /// 统一的头部高度（侧边栏顶部和详情栏头部）
    static let headerHeight: CGFloat = 44
    
    // MARK: - SwiftData Configuration
    /// 获取配置好的 SwiftData 模型容器
    /// - Returns: 配置完整的 ModelContainer 实例
    static func getContainer() -> ModelContainer {
        let schema = Schema([
            Conversation.self,
            ChatMessageEntity.self
        ])

        // 获取数据库文件路径（不是目录）
        let dbFileURL = getDBFileURL()
        
        // 配置 SwiftData 容器，使用自定义存储路径
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: dbFileURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Directory Helpers

    /// 获取当前应用的 App Support 目录
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
    /// - Returns: 容器目录的 URL，如果不存在则返回 nil
    static var localContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.bundleIdentifier ?? "")
    }

    /// 获取文档目录
    /// - Returns: 文档目录的 URL，如果不存在则返回 nil
    static var localDocumentsDir: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// 获取数据库文件夹目录
    /// - Returns: 数据库目录的 URL
    static func getDBFolderURL() -> URL {
        let appSupport = getCurrentAppSupportDir()
        
        #if DEBUG
        let dbDirectoryName = "db_debug"
        #else
        let dbDirectoryName = "db_production"
        #endif
        
        let dbDirectory = appSupport.appendingPathComponent(dbDirectoryName, isDirectory: true)
        
        // 确保数据库目录存在
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: dbDirectory.path) {
            try? fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return dbDirectory
    }
    
    /// 获取数据库文件路径（包含具体文件名）
    /// - Returns: 数据库文件的 URL
    static func getDBFileURL() -> URL {
        let dbDirectory = getDBFolderURL()
        return dbDirectory.appendingPathComponent("Lumi.db")
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
