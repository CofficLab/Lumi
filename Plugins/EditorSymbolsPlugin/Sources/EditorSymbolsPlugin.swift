import EditorService
import LumiKernel
import LumiUI
import SwiftUI

public enum EditorSymbolsPanelPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-symbols",
        displayName: LumiPluginLocalization.string("Editor Symbols", bundle: .module),
        description: LumiPluginLocalization.string("Symbols panel in the editor rail and bottom area.", bundle: .module),
        order: 3,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "list.bullet.rectangle",
    )

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
