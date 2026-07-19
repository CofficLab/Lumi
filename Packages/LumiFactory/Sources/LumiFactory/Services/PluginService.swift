import Foundation
import LumiKernel
import ProjectPlugin
import StoragePlugin
import os

/// 插件服务
///
/// 维护静态插件列表，包含所有内置插件。
@MainActor
public enum PluginService {

    // MARK: - Plugin List

    /// 所有插件列表（静态）
    public static let plugins: [LumiPlugin] = {
        var list: [LumiPlugin] = []

        // StoragePlugin
        if let plugin = try? StoragePlugin() {
            list.append(plugin)
        }

        // ProjectPlugin
        list.append(ProjectPlugin())

        return list
    }()
}