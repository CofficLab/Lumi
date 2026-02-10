import Foundation
import SwiftData
import SwiftUI

/// 应用配置管理器，负责SwiftData容器配置和应用级设置
enum AppConfig {
    /// 获取配置好的SwiftData模型容器
    /// - Returns: 配置完整的ModelContainer实例
    static func getContainer() -> ModelContainer {
        let schema = Schema([
            // 您的模型类型将在这里注册
        ])

        // 配置SwiftData容器
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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

        let bundleID = Bundle.main.bundleIdentifier ?? "com.cofficlab.App"
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
        return appSupport.appendingPathComponent("Database", isDirectory: true)
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
