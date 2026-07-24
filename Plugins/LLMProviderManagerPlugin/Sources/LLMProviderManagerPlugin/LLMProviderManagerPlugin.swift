import Foundation
import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// LLM Provider Manager Plugin
///
/// Registers an `LLMProviderProviding` implementation with the kernel.
/// Individual LLM Provider plugins call
/// `kernel.llmProvider?.registerLLMProvider(...)` in their own
/// `register(kernel:)` to make themselves available.
///
/// Order = 10 (after `PluginManagementPlugin` order 5, before any
/// LLM Provider plugin in the 100+ range), so that the manager is in
/// place when downstream LLM provider plugins attempt to register.
@MainActor
public final class LLMProviderManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider-manager")
    public nonisolated static let emoji = "🧠"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.llm-provider-manager"
    public let name = "LLM Provider Manager"
    public let order = 10
    public let policy: LumiPluginPolicy = .alwaysOn // 核心插件

    private var manager: LLMProviderManager?

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        let service = LLMProviderManager()
        manager = service
        kernel.registerLLMProviderService(service)
        kernel.registerLLMProviderSettingsService(service)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 LLMProviderManager 到内核")
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        #if DEBUG
            [MockLLMProvider()]
        #else
            []
        #endif
    }

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

    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        // 始终注册两个 tab。具体的依赖解析在 contentBuilder 内延迟进行,
        // 这样依赖缺失时侧边栏仍可见,错误信息由 `ProviderDependencySettingsView`
        // 在详情页顶部以 `AppErrorBanner` + `DependenciesMissingDetailView` 展示。
        //
        // `manager` 通过 `@autoclosure` 传入,优先使用插件实例属性(避免每次 tab
        // 重新构建时的反射查找开销),仅有意外情况下才回退到 kernel 服务表。
        return [
            SettingsTabItem(
                id: "\(id).local",
                title: "Local Providers",
                systemImage: "cpu"
            ) {
                let state = SettingsTabDependencyState.resolve(
                    kernel: kernel,
                    managerAccessor: self.manager
                )
                return AnyView(
                    ProviderDependencySettingsView(dependencyState: state) { chatService, manager in
                        let views = manager.llmProviderSettingsViews(lumiCore: kernel.lumiCore)
                        return LocalProviderSettingsPage(
                            chatService: chatService,
                            providerSettingsViews: views,
                            availability: manager.providerAvailabilityState
                        )
                    }
                )
            },
            SettingsTabItem(
                id: "\(id).remote",
                title: "Cloud Providers",
                systemImage: "network"
            ) {
                let state = SettingsTabDependencyState.resolve(
                    kernel: kernel,
                    managerAccessor: self.manager
                )
                return AnyView(
                    ProviderDependencySettingsView(dependencyState: state) { chatService, manager in
                        let views = manager.llmProviderSettingsViews(lumiCore: kernel.lumiCore)
                        return RemoteProviderSettingsPage(
                            chatService: chatService,
                            providerSettingsViews: views,
                            availability: manager.providerAvailabilityState
                        )
                    }
                )
            },
        ]
    }

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
