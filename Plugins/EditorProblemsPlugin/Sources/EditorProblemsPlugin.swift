import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorProblemsPanelPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-bottom-problems",
        displayName: LumiPluginLocalization.string("Editor Problems", bundle: .module),
        description: LumiPluginLocalization.string("Problems panel in the editor rail and bottom area.", bundle: .module),
        order: 1,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "exclamationmark.triangle",
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
                id: "editor-bottom-problems",
                order: info.order,
                title: LumiPluginLocalization.string("Problems", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorProblemsPanelView(service: service, showsHeader: false)
            }
        ]
    }

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelRailTabItem(
                id: "problems",
                order: info.order,
                title: LumiPluginLocalization.string("Problems", bundle: .module),
                systemImage: iconName
            ) {
                BottomEditorProblemsPanelView(service: service, showsHeader: false)
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
