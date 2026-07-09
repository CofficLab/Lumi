import LumiCoreKit
import LumiUI
import os
import SwiftUI

public enum QuickLauncherPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.quicklauncher")
    public static let verbose = false
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .system
    public static let iconName = "app.grid"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.quick-launcher",
        displayName: LumiPluginLocalization.string("Quick Launcher", bundle: .module),
        description: LumiPluginLocalization.string("Quick access to system apps and utilities", bundle: .module),
        order: 8
    )

    @MainActor
    public static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        [
            LumiMenuBarPopupItem(id: "\(info.id).launcher", order: info.order) {
                QuickLauncherMenuBarPopupView()
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
