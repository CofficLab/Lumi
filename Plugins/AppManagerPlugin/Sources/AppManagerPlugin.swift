import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum AppManagerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-manager")
    public static let verbose = false
    /// 数据根目录解析器。默认走 fallback,由 `bootstrapFromLumiCoreIfNeeded`
    /// 在 @MainActor 上下文覆盖为真实路径(替代旧的 nonisolated 镜像)。
    nonisolated(unsafe) public static var databaseRootURLProvider: () -> URL = {
        AppManagerPluginRuntimeBridge.fallbackRootDirectory
    }


    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.app-manager",
        displayName: PluginAppManagerLocalization.string("App Manager"),
        description: PluginAppManagerLocalization.string("Browse installed macOS applications."),
        order: 42,
        category: .system,
        policy: .optIn,
        stage: .beta,
        iconName: "apps.ipad",
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        bootstrapFromLumiCoreIfNeeded(context: context)
        return [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                AppManagerView()
            }
        ]
    }

    @MainActor
    public static func pluginAboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(AppManagerAboutView())
    }

    @MainActor
    public static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "square.grid.2x2",
                            title: PluginAppManagerLocalization.string("Browse apps"),
                            description: PluginAppManagerLocalization.string("See all installed macOS applications")
                        ),
                        .init(
                            icon: "magnifyingglass",
                            title: PluginAppManagerLocalization.string("Search"),
                            description: PluginAppManagerLocalization.string("Find apps by name instantly")
                        ),
                    ],
                    tip: PluginAppManagerLocalization.string("Open App Manager from the sidebar to explore your apps.")
                )
            )
        ]
    }
}
