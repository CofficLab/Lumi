import LumiCoreKit
import LumiUI
import SwiftUI

public enum OpenInCursorPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.open-in-cursor",
        displayName: LumiPluginLocalization.string("Open in Cursor", bundle: .module),
        description: LumiPluginLocalization.string("Open current file or project in Cursor editor.", bundle: .module),
        order: 60,
        category: .development,
        policy: .disabled,
        stage: .beta,
        iconName: "cursor",
    )

    @MainActor
    public static func statusBarItems(lumiCore: any LumiCoreAccessing) -> [LumiStatusBarItem] {
        [
            LumiStatusBarItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    OpenInCursorStatusBarView()
                }
            )
        ]
    }

    @MainActor
    public static func pluginAboutView(lumiCore: any LumiCoreAccessing) -> AnyView? {
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
