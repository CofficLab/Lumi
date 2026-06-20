import Foundation
import EditorService
import LumiCoreKit

@MainActor
public final class MinimapContextMenuCommandContributor: SuperEditorCommandContributor {
    public let id: String = "builtin.minimap.context-menu"

    public func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        guard textView != nil else { return [] }

        let isVisible = state.showMinimap
        let title = isVisible
            ? LumiPluginLocalization.string("Hide Minimap", bundle: .module)
            : LumiPluginLocalization.string("Show Minimap", bundle: .module)
        let systemImage = isVisible ? "map.fill" : "map"

        return [
            .init(
                id: "builtin.toggle-minimap",
                title: title,
                systemImage: systemImage,
                category: EditorCommandCategory.workbench.rawValue,
                order: 5,
                isEnabled: true
            ) {
                state.toggleShowMinimapPersisted()
            }
        ]
    }
}
