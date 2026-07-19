import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum FontConfigPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.font-config")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.font-config",
        displayName: LumiPluginLocalization.string("Font Config", bundle: .module),
        description: LumiPluginLocalization.string("Quick font switching in status bar", bundle: .module),
        order: 78,
        category: .theme,
        policy: .disabled,
        stage: .beta,
        iconName: "textformat",
    )

    @MainActor
    public static func statusBarItems(context: any LumiCoreAccessing) -> [LumiStatusBarItem] {
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
    public static func pluginAboutView(context: any LumiCoreAccessing) -> AnyView? {
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
