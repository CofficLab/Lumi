import LumiCoreKit
import SwiftUI

public enum AppStoreConnectPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "bag"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.app-store-connect",
        displayName: AppStoreConnectLocalization.string("App Store"),
        description: AppStoreConnectLocalization.string("Manage App Store Connect apps, metadata, and screenshots"),
        order: 65
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var description: String { info.description }
    public static var order: Int { info.order }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            ListAppStoreConnectAppsTool(),
            ListAppStoreConnectVersionsTool(),
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
            SetAppStoreConnectCiWorkflowEnabledTool()
        ]
    }

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        guard context.activeSectionID == info.id else { return [] }

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
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        let projectPathProvider = context.resolve(LumiCurrentProjectPathStoring.self)
        AppStoreConnectAddToChat.currentProjectPathProvider = {
            projectPathProvider?.currentProjectPath ?? ""
        }
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
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(AppStoreConnectAboutView())
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
