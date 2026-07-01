import LumiCoreKit
import LumiUI
import SwiftUI

public enum FontConfigPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .theme
    public static let iconName = "textformat"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.font-config",
        displayName: LumiPluginLocalization.string("Font Config", bundle: .module),
        description: LumiPluginLocalization.string("Quick font switching in status bar", bundle: .module),
        order: 78
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        [
            LumiStatusBarItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    FontStatusBarView()
                }
            )
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
