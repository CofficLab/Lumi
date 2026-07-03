import LumiCoreKit
import os

/// Collects OSLog entries to rotating on-disk log files.
public enum FileLogPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .system
    public static let iconName = "doc.text.below.ecg"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-log")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.file-log",
        displayName: LumiPluginLocalization.string("File Log", bundle: .module),
        description: LumiPluginLocalization.string("Collect OSLog entries to disk files with auto-rotation and cleanup", bundle: .module),
        order: 1
    )

    nonisolated(unsafe) public static var configuration: FileLogConfiguration = DefaultFileLogConfiguration()

    public static func bootstrapIfNeeded() {
        FileLogCoordinator.shared.start()
    }
}
