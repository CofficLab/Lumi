import LumiCoreKit
import LumiUI
import SwiftUI

public enum IdleTimePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .general
    public static let iconName = "moon.zzz"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.idle-time",
        displayName: String(localized: "Idle Time", bundle: .module),
        description: String(localized: "Infer rest windows for background scheduling", bundle: .module),
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
}
