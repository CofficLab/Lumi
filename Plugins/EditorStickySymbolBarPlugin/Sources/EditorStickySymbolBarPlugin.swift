import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorStickySymbolBarHeaderPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "point.topleft.down.curvedto.point.bottomright.up"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-sticky-symbol-bar-header",
        displayName: LumiPluginLocalization.string("Editor Sticky Symbol Bar", bundle: .module),
        description: LumiPluginLocalization.string("Current symbol breadcrumb for the editor panel.", bundle: .module),
        order: 89
    )

    @MainActor
    public static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        guard context.showsPanelChrome,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelHeaderItem(id: info.id, order: info.order) {
                EditorStickySymbolBarHeaderView(service: service)
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
