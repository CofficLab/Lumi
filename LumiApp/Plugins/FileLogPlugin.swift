import Foundation
import PluginFileLog
import os

actor FileLogPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-log")

    nonisolated static let emoji = "📋"
    static var category: PluginCategory { .system }
    nonisolated static let enable: Bool = PluginFileLog.FileLogPlugin.enable
    nonisolated static let verbose: Bool = PluginFileLog.FileLogPlugin.verbose

    static let id = PluginFileLog.FileLogPlugin.id
    static let navigationId = PluginFileLog.FileLogPlugin.navigationId
    static let displayName = PluginFileLog.FileLogPlugin.displayName
    static let description = PluginFileLog.FileLogPlugin.description
    static let iconName = PluginFileLog.FileLogPlugin.iconName
    static let isConfigurable = PluginFileLog.FileLogPlugin.isConfigurable
    static var order: Int { PluginFileLog.FileLogPlugin.order }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = FileLogPlugin()

    nonisolated func onRegister() {
        PluginFileLog.FileLogPlugin.configuration = AppFileLogConfiguration()
    }

    nonisolated func onEnable() {
        PluginFileLog.FileLogPlugin.shared.onEnable()
    }

    nonisolated func onDisable() {
        PluginFileLog.FileLogPlugin.shared.onDisable()
    }
}

private struct AppFileLogConfiguration: FileLogConfiguration {
    func logsDirectory() -> URL {
        AppConfig.getPluginDBFolderURL(pluginName: "FileLog")
    }
}
