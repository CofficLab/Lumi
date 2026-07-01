import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorReferencesPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "arrow.triangle.branch"
    private static let railTabOrder = 11

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-references",
        displayName: LumiPluginLocalization.string("Editor References", bundle: .module),
        description: LumiPluginLocalization.string("References panel in the editor rail and bottom area.", bundle: .module),
        order: 1
    )

    @MainActor
    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
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
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail,
              context.activeSectionID == LumiEditorPanelContainer.id,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelRailTabItem(
                id: "references",
                order: railTabOrder,
                title: LumiPluginLocalization.string("References", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
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
