import Foundation
import KernelLumi
import SuperLogKit
import SwiftUI
import os

/// 存储插件
///
/// 向 KernelLumi 注册 Storage 服务。
@MainActor
public final class StoragePlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.storage")
    nonisolated public static let emoji = "💾"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.storage"
    public var name: String {
        LumiPluginLocalization.string("Storage Plugin", bundle: .module)
    }
    public let order = 10
    public let policy: LumiPluginPolicy = .alwaysOn  // 核心插件，最先加载
    public let stage: LumiPluginStage = .beta

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

    public func onBoot(kernel: KernelLumi) async throws {
        try await StorageOnBootHook(dataRootDirectory: dataRootDirectory).execute(kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        try StorageOnReadyHook(dataRootDirectory: dataRootDirectory).execute(kernel)
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
