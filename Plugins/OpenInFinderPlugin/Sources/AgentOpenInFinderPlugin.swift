import LumiCoreKit
import LumiUI
import SwiftUI

public enum OpenInFinderPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.open-in-finder",
        displayName: LumiPluginLocalization.string("Open in Finder", bundle: .module),
        description: LumiPluginLocalization.string("Open current file or project in Finder.", bundle: .module),
        order: 61,
        category: .development,
        policy: .disabled,
        stage: .beta,
        iconName: "finder",
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
                    OpenInFinderStatusBarView()
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
