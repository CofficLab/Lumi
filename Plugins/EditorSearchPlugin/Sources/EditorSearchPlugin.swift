import EditorService
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class EditorSearchPanelPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-bottom-search"
    public let name = "Editor Search"
    public let order = 2
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Panel items are registered in panelBottomTabItems/panelRailTabItems methods
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] {
        guard let service = kernel.editor?.editorService else {
            return []
        }

        return [
            PanelBottomTabItem(
                id: "editor-bottom-search",
                order: order,
                title: "Search",
                systemImage: "magnifyingglass"
            ) {
                BottomEditorWorkspaceSearchPanelView(service: service, showsToolbar: true)
            }
        ]
    }

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        guard let service = kernel.editor?.editorService else {
            return []
        }

        return [
            PanelRailTabItem(
                id: "search",
                order: order,
                title: "Search",
                systemImage: "magnifyingglass"
            ) {
                BottomEditorWorkspaceSearchPanelView(service: service, showsToolbar: true)
            }
        ]
    }
}
