import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

@MainActor
public final class AppIconDesignerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🎨"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.app-icon-designer"
    )

    public let id = "com.coffic.lumi.plugin.app-icon-designer"
    public var name: String {
        AppIconDesignerLocalization.string("AppIconDesigner Name")
    }

    public let order = 79
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta
    public var pluginDescription: String {
        AppIconDesignerLocalization.string("Design app icons with shapes, layers, and export capabilities.")
    }

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        IconDocumentStore.shared.configure(
            persistenceDirectory: kernel.storage?.pluginDataDirectory(for: "AppIconDesigner")
        )
    }

    public func onReady(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("🎨 AppIconDesigner 插件初始化完成")
        }
    }

    // MARK: - Agent Tools

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            CreateIconDocumentTool(),
            ApplyIconPresetTool(),
            LoadIconDocumentTool(),
            SaveIconDocumentTool(),
            SetIconBackgroundTool(),
            AddIconShapeTool(),
            UpdateIconShapeTool(),
            UpdateIconLayerTool(),
            LintIconDocumentTool(),
            PreviewIconTool(),
            ExportIconSVGTool(),
            ExportAppIconTool(),
            RegisterAppIconArtifactTool(),
        ]
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: name,
                placement: .center,
                order: 0
            ) {
                Text(self.name)
                    .font(.system(size: 13, weight: .semibold))
            },
        ]
    }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "app-icon-designer.documents",
                title: AppIconDesignerLocalization.string("Icon Documents"),
                systemImage: "doc.text",
                visibility: .viewContainer(id: id)
            ) {
                AppIconDesignerRailView()
            },
        ]
    }

    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "app.dashed",
                railVisibility: .alwaysVisible,
                chatVisibility: .alwaysVisible,
                panelHeaderVisibility: .unsupported,
                panelBodyVisibility: .alwaysVisible,
                panelBottomVisibility: .unsupported
            ) {
                DesignerView()
            },
        ]
    }

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(DesignerAboutView())
    }

    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
