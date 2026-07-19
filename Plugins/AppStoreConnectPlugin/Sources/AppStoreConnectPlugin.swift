import LumiKernel
import LumiUI
import SwiftUI

public enum AppStoreConnectPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.app-store-connect",
        displayName: AppStoreConnectLocalization.string("App Store"),
        description: AppStoreConnectLocalization.string("Manage App Store Connect apps, metadata, and screenshots"),
        order: 65,
        category: .development,
        policy: .optIn,
        stage: .beta,
        iconName: "bag",
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var description: String { info.description }
    public static var order: Int { info.order }

    @MainActor
    public static func agentTools(lumiCore: any LumiCoreAccessing) -> [any LumiAgentTool] {
        bootstrapFromLumiCoreIfNeeded(context: lumiCore)
        return [
            ListAppStoreConnectAppsTool(),
            ListAppStoreConnectVersionsTool(),
            CreateAppStoreConnectVersionTool(),
            ListAppStoreConnectLocalizationsTool(),
            ListAppStoreConnectScreenshotSetsTool(),
            ListAppStoreConnectScreenshotsTool(),
            ListAppStoreConnectCiProductsTool(),
            ListAppStoreConnectCiWorkflowsTool(),
            ReadAppStoreConnectCiWorkflowTool(),
            ListAppStoreConnectCiBuildRunsTool(),
            UpdateAppStoreConnectLocalizationTool(),
            CreateAppStoreConnectScreenshotSetTool(),
            StartAppStoreConnectCiBuildRunTool(),
            SetAppStoreConnectCiWorkflowEnabledTool(),
            ListAppStoreConnectCoverArtTool(),
            ReadAppStoreConnectCoverArtTool(),
            CreateAppStoreConnectCoverArtTool(),
            UpdateAppStoreConnectCoverArtTool(),
            ExportAppStoreConnectCoverArtTool()
        ]
    }

    @MainActor
    public static func titleToolbarItems(lumiCore: any LumiCoreAccessing) -> [LumiTitleToolbarItem] {
        guard lumiCore.layoutComponent.state.activeSectionID == info.id else { return [] }

        return [
            LumiTitleToolbarItem(
                id: "\(info.id).app-picker",
                title: AppStoreConnectLocalization.string("Select App"),
                placement: .center
            ) {
                ToolbarAppPicker()
            }
        ]
    }

    @MainActor
    public static func viewContainers(lumiCore: any LumiCoreAccessing) -> [LumiViewContainerItem] {
        let provider: @MainActor @Sendable () -> String = {
            lumiCore.projectComponent.currentProject?.path ?? ""
        }
        AddToChat.currentProjectPathProvider = provider
        CoverArtRuntime.currentProjectPathProvider = provider
        return [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                chatSection: .narrow
            ) {
                MainView()
            }
        ]
    }

    @MainActor
    public static func pluginAboutView(lumiCore: any LumiCoreAccessing) -> AnyView? {
        AnyView(AboutView())
    }

    @MainActor
    public static func onboardingPages(lumiCore: any LumiCoreAccessing) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "square.grid.2x2",
                            title: AppStoreConnectLocalization.string("Apps & versions"),
                            description: AppStoreConnectLocalization.string("Browse apps, versions, and localizations")
                        ),
                        .init(
                            icon: "hammer.fill",
                            title: AppStoreConnectLocalization.string("CI"),
                            description: AppStoreConnectLocalization.string("Trigger and watch Xcode Cloud workflows")
                        ),
                    ],
                    tip: AppStoreConnectLocalization.string("Open App Store from the sidebar and pick an app to begin.")
                )
            )
        ]
    }
}

enum AppStoreConnectLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: args)
    }
}
