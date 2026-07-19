import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorReferencesPanelPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-references",
        displayName: LumiPluginLocalization.string("Editor References", bundle: .module),
        description: LumiPluginLocalization.string("References panel in the editor rail and bottom area.", bundle: .module),
        order: 3,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "doc.on.doc",
    )

    @MainActor
    public static func panelBottomTabItems(context: any LumiCoreAccessing) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelBottomTabItem(
                id: "editor-bottom-references",
                order: info.order,
                title: LumiPluginLocalization.string("References", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
            }
        ]
    }

    @MainActor
    public static func panelRailTabItems(context: any LumiCoreAccessing) -> [LumiPanelRailTabItem] {
        guard context.showsRail,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelRailTabItem(
                id: "references",
                order: info.order,
                title: LumiPluginLocalization.string("References", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
            }
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
