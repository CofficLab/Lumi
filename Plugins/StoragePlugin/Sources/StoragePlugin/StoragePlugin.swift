import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 存储插件
///
/// 向 LumiKernel 注册 Storage 服务。
@MainActor
public final class StoragePlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.storage")
    nonisolated public static let emoji = "💾"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.storage"
    public let name = "Storage Plugin"
    public let order = 10
    public let policy: LumiPluginPolicy = .alwaysOn  // 核心插件，最先加载

    /// 数据根目录
    private let dataRootDirectory: URL

    // MARK: - Initialization

    public init(dataRootDirectory: URL? = nil) throws {
        if let dataRootDirectory {
            self.dataRootDirectory = dataRootDirectory
        } else {
            self.dataRootDirectory = try Self.makeDefaultDataRootDirectory()
        }
    }

    /// 使用默认目录创建
    public convenience init() throws {
        try self.init(dataRootDirectory: nil)
    }

    // MARK: - Factory Methods

    /// 创建默认数据根目录
    /// 路径格式：<Application Support>/<bundleID>/db_<debug|production>_v<majorVersion>
    private static func makeDefaultDataRootDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4"
        let majorVersion = version.split(separator: ".").first.flatMap { Int($0) } ?? 4

        #if DEBUG
        let dbDirectoryName = "db_debug_v\(majorVersion)"
        #else
        let dbDirectoryName = "db_production_v\(majorVersion)"
        #endif

        let dataRoot = appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(dbDirectoryName, isDirectory: true)

        try FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)
        return dataRoot
    }

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        let storage = StorageService(dataRootDirectory: dataRootDirectory)
        kernel.registerStorage(storage)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Storage 服务: \(self.dataRootDirectory.path)")
        }
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
