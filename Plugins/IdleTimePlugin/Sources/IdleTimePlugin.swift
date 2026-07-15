import LumiCoreKit
import LumiUI
import SwiftUI

public enum IdleTimePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
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
        bootstrapFromLumiCoreIfNeeded(context: context)
        return [IdleTimeChatMiddleware()]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == "LumiEditor" else {
            return []
        }

        let projectPath = context.lumiCore?.projectState?.currentProject?.path ?? ""
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
        bootstrapFromLumiCoreIfNeeded(context: context)
        let projectPathProvider = {
            context.lumiCore?.projectState?.currentProject?.path ?? ""
        }
        return [
            LumiRootOverlayItem(id: "\(info.id).observer", order: info.order) { content in
                IdleTimeRootObserver(projectPathProvider: projectPathProvider, content: content)
            }
        ]
    }

        @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

}
