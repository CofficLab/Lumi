import Foundation
import LumiChatKit
import EditorService
import LumiCoreKit
import SuperLogKit
import os

@MainActor
final class LumiCoreService: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.lumi-core")
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = true

    let dataRootDirectory: URL
    let coreDatabaseDirectory: URL

    init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 LumiCoreService")
        }

        let dataRootDirectory = Self.makeDataRootDirectory()
        AppConfig.configure(dataRootDirectory: dataRootDirectory)
        self.dataRootDirectory = dataRootDirectory
        self.coreDatabaseDirectory = Self.makeCoreDatabaseDirectory(in: dataRootDirectory)

        // 启动 LumiCore
        LumiCore.boot()

        if Self.verbose {
            Self.logger.info("\(Self.t)数据根目录: \(dataRootDirectory.path)")
            Self.logger.info("\(Self.t)核心数据库目录: \(self.coreDatabaseDirectory.path)")
            Self.logger.info("\(Self.t)✅ LumiCoreService 初始化完成")
        }
    }

    // MARK: - Plugin Context Factory

    /// 统一创建 `LumiPluginContext`，自动注册传入的非空服务依赖。
    /// - Parameters:
    ///   - activeSectionID: 当前活跃区域 ID。
    ///   - activeSectionTitle: 当前活跃区域标题。
    ///   - chatSection: 聊天区布局配置。
    ///   - showsRail: 是否显示侧边栏。
    ///   - showsPanelChrome: 是否显示面板边框。
    ///   - isChatSectionVisible: 聊天区是否可见。
    ///   - chatService: 聊天服务实例。
    ///   - editorService: 编辑器服务实例。
    ///   - toolService: 工具服务实例。
    ///   - chatSectionCoordinator: 聊天区协调器。
    ///   - panelLayoutPresenter: 底部面板布局 presenter。
    ///   - historyQueryService: 历史查询服务实例。
    ///   - additionalDependencies: 额外依赖注册回调。
    /// - Returns: 初始化完成的 `LumiPluginContext`。
    func makePluginContext(
        activeSectionID: String,
        activeSectionTitle: String,
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        isChatSectionVisible: Bool? = nil,
        chatService: (any LumiChatServicing)? = nil,
        editorService: LumiEditorServicing? = nil,
        toolService: ToolService? = nil,
        chatSectionCoordinator: ChatSectionCoordinator? = nil,
        panelLayoutPresenter: LumiBottomPanelLayoutPresenting? = nil,
        historyQueryService: (any HistoryQueryService)? = nil,
        additionalDependencies: (inout LumiPluginDependencies) -> Void = { _ in }
    ) -> LumiPluginContext {
        var dependencies = LumiPluginDependencies()

        if let chatService {
            dependencies.register((any LumiChatServicing).self, chatService)
        }
        if let editorService {
            dependencies.register(LumiEditorServicing.self, editorService)
        }
        if let toolService {
            dependencies.register(ToolService.self, toolService)
        }
        if let chatSectionCoordinator {
            dependencies.register(ChatSectionCoordinator.self, chatSectionCoordinator)
        }
        if let panelLayoutPresenter {
            dependencies.register(LumiBottomPanelLayoutPresenting.self, panelLayoutPresenter)
        }
        if let historyQueryService {
            dependencies.register((any HistoryQueryService).self, historyQueryService)
        }

        additionalDependencies(&dependencies)

        return LumiPluginContext(
            activeSectionID: activeSectionID,
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: isChatSectionVisible,
            dependencies: dependencies
        )
    }

    // MARK: - Private

    private static func makeDataRootDirectory() -> URL {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to resolve Application Support directory.")
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        let versionSuffix = "v\(majorVersion(from: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String))"

        #if DEBUG
        let databaseDirectoryName = "db_debug_\(versionSuffix)"
        #else
        let databaseDirectoryName = "db_production_\(versionSuffix)"
        #endif

        let dataRootDirectory = appDirectory.appendingPathComponent(databaseDirectoryName, isDirectory: true)
        try? fileManager.createDirectory(
            at: dataRootDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return dataRootDirectory
    }

    private static func makeCoreDatabaseDirectory(in dataRootDirectory: URL) -> URL {
        let coreDirectory = dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: coreDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return coreDirectory
    }

    private static func majorVersion(from version: String?) -> Int {
        guard let version,
              let major = version.split(separator: ".").first,
              let value = Int(major)
        else {
            return 1
        }

        return value
    }
}
