import LumiCoreKit
import LumiUI
import SwiftUI

public enum OpenRemotePlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.open-remote",
        displayName: LumiPluginLocalization.string("Open Remote", bundle: .module),
        description: LumiPluginLocalization.string("Open current file or project in remote editor.", bundle: .module),
        order: 62,
        category: .development,
        policy: .disabled,
        stage: .beta,
        iconName: "remote",
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
                    OpenRemoteStatusBarView()
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
