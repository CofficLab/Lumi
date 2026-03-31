import Foundation
import SwiftData

/// 数据库配置管理器
///
/// 负责 SwiftData 容器配置和数据库路径管理。
enum DBConfig {
    
    // MARK: - Schema Definition
    
    /// 获取 SwiftData Schema 定义
    ///
    /// 包含所有持久化的数据模型：
    /// - `Conversation`: 对话会话
    /// - `ChatMessageEntity`: 聊天消息
    /// - `MessageMetricsEntity`: 消息性能指标
    /// - `ImageAttachmentEntity`: 图片附件
    ///
    /// - Returns: 配置好的 Schema 对象
    static func getSchema() -> Schema {
        Schema([
            Conversation.self,
            ChatMessageEntity.self,
            MessageMetricsEntity.self,
            ImageAttachmentEntity.self
        ])
    }
    
    // MARK: - Container Configuration
    
    /// 获取配置好的 SwiftData 模型容器
    ///
    /// 创建并返回一个配置完整的 ModelContainer 实例，
    /// 使用自定义存储路径。
    ///
    /// - Returns: 配置完整的 ModelContainer 实例
    static func getContainer() -> ModelContainer {
        let schema = getSchema()
        let dbFileURL = getDBFileURL()
        
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
    
    // MARK: - Database Paths
    
    /// 获取数据库文件夹目录（应用主库与插件子目录的根目录）
    ///
    /// 路径格式：
    /// - Debug: `~/Library/Application Support/com.cofficlab.Lumi/db_debug`
    /// - Release: `~/Library/Application Support/com.cofficlab.Lumi/db_production`
    ///
    /// - Returns: 数据库目录的 URL
    static func getDBFolderURL() -> URL {
        let appSupport = getAppSupportDirectory()
        
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
    
    /// Core 数据目录
    ///
    /// 存放应用核心数据的数据库文件。
    /// 路径：`getDBFolderURL() / Core`
    ///
    /// - Returns: Core 数据目录的 URL
    static func getCoreDBFolderURL() -> URL {
        let coreDirectory = getDBFolderURL().appendingPathComponent("Core", isDirectory: true)
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: coreDirectory.path) {
            try? fileManager.createDirectory(at: coreDirectory, withIntermediateDirectories: true)
        }
        return coreDirectory
    }
    
    /// 获取数据库文件路径（包含具体文件名）
    ///
    /// 路径：`getCoreDBFolderURL() / Lumi.db`
    ///
    /// - Returns: 数据库文件的 URL
    static func getDBFileURL() -> URL {
        let coreDirectory = getCoreDBFolderURL()
        return coreDirectory.appendingPathComponent("Lumi.db")
    }
    
    /// 获取指定插件的数据库/存储目录
    ///
    /// 插件自行管理该目录下的文件或数据库。
    /// 路径格式：`getDBFolderURL() / pluginName`
    ///
    /// - Parameter pluginName: 插件名称，建议与插件模块名一致（如 "GitHubToolsPlugin"）
    /// - Returns: 该插件的存储目录 URL，不存在时会自动创建
    static func getPluginDBFolderURL(pluginName: String) -> URL {
        let base = getDBFolderURL()
        
        // 清理插件名称，移除特殊字符
        let sanitized = pluginName.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        
        let name = sanitized.isEmpty ? "Plugin" : sanitized
        let pluginDir = base.appendingPathComponent(name, isDirectory: true)
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: pluginDir.path) {
            try? fileManager.createDirectory(at: pluginDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        return pluginDir
    }
    
    // MARK: - Application Directory Helpers
    
    /// 获取当前应用的 App Support 目录
    ///
    /// 路径格式：`~/Library/Application Support/com.cofficlab.Lumi`
    ///
    /// - Returns: App Support 目录的 URL
    private static func getAppSupportDirectory() -> URL {
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
}

// MARK: - Database Information

extension DBConfig {
    
    /// 数据库信息
    struct DatabaseInfo {
        let dbFileURL: URL
        let dbFolderURL: URL
        let coreFolderURL: URL
        let dbSizeInBytes: Int64
        let dbSizeFormatted: String
    }
    
    /// 获取数据库信息
    ///
    /// 返回数据库文件的路径、大小等信息。
    ///
    /// - Returns: 数据库信息对象
    static func getDatabaseInfo() -> DatabaseInfo {
        let dbFileURL = getDBFileURL()
        let dbFolderURL = getDBFolderURL()
        let coreFolderURL = getCoreDBFolderURL()
        
        // 获取文件大小
        let attributes = try? FileManager.default.attributesOfItem(atPath: dbFileURL.path)
        let dbSizeInBytes = (attributes?[.size] as? Int64) ?? 0
        let dbSizeFormatted = ByteCountFormatter.string(fromByteCount: dbSizeInBytes, countStyle: .file)
        
        return DatabaseInfo(
            dbFileURL: dbFileURL,
            dbFolderURL: dbFolderURL,
            coreFolderURL: coreFolderURL,
            dbSizeInBytes: dbSizeInBytes,
            dbSizeFormatted: dbSizeFormatted
        )
    }
    
    /// 打印数据库信息（用于调试）
    static func printDatabaseInfo() {
        let info = getDatabaseInfo()
        
        // 获取文件名的最后3个组件
        let pathComponents = info.dbFileURL.path.components(separatedBy: "/")
        let fileName = pathComponents.suffix(3).joined(separator: "/")
        
        print("╔════════════════════════════════════════╗")
        print("║        Lumi Database Information       ║")
        print("╠════════════════════════════════════════╣")
        print("║ File:    \(fileName)")
        print("║ Size:    \(info.dbSizeFormatted)")
        print("║ Path:    \(info.dbFolderURL.path)")
        print("╚════════════════════════════════════════╝")
    }
}
