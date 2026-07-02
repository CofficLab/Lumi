import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public enum EditorOutlinePanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "list.bullet.indent"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-outline",
        displayName: LumiPluginLocalization.string("Editor Outline", bundle: .module),
        description: LumiPluginLocalization.string("Outline tab in the editor rail.", bundle: .module),
        order: 1
    )

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail,
              let service = context.resolve(LumiEditorServicing.self)?.editorService
        else {
            return []
        }

        return [
            LumiPanelRailTabItem(
                id: "outline",
                order: info.order,
                title: LumiPluginLocalization.string("Outline", bundle: .module),
                systemImage: iconName
            ) {
                if let provider = service.lsp.documentSymbolProvider as? DocumentSymbolProvider {
                    EditorOutlinePanelView(
                        service: service,
                        provider: provider,
                        showsHeader: false,
                        showsResizeHandle: false
                    )
                } else {
                    Text(LumiPluginLocalization.string("Outline not available", bundle: .module))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        ]
    }
}
