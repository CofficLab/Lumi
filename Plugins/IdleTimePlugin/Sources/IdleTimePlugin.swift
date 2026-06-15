import LumiCoreKit
import SwiftUI

public enum IdleTimePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .general
    public static let iconName = "moon.zzz"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.idle-time",
        displayName: LumiPluginLocalization.string("Idle Time", bundle: .module),
        description: LumiPluginLocalization.string("Infer rest windows for background scheduling", bundle: .module),
        order: 96
    )

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        bootstrapFromLumiCoreIfNeeded()
        return [IdleTimeChatMiddleware()]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == "LumiEditor" else {
            return []
        }

        let projectPath = context.resolve(LumiCurrentProjectPathProviding.self)?.currentProjectPath ?? ""
        return [
            LumiStatusBarItem(
                id: "\(info.id).status",
                title: info.displayName,
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    IdleStatusBarView(projectPath: projectPath)
                }
            )
        ]
    }

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        bootstrapFromLumiCoreIfNeeded()
        let projectPathProvider = {
            context.resolve(LumiCurrentProjectPathProviding.self)?.currentProjectPath ?? ""
        }
        return [
            LumiRootOverlayItem(id: "\(info.id).observer", order: 96) { content in
                IdleTimeRootObserver(projectPathProvider: projectPathProvider, content: content)
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "moon.zzz", title: "Idle Time", description: "Infer rest windows for background scheduling"),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates Idle Time into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable Idle Time in plugin settings",
                "The plugin registers its contributions when enabled",
                "Use the features provided in the Lumi workspace"
            ],
            tips: [
                "Toggle the plugin off if you do not need this feature",
                "Check plugin settings for additional options"
            ]
        )
    }

}
