import Foundation
import LayoutPlugin

@MainActor
public final class EditorWorkspaceLayoutState: ObservableObject {
    @Published public var railVisible: Bool
    @Published public var bottomPanelVisible: Bool
    @Published public var bottomPanelHeight: CGFloat
    @Published public var activeRailTabID: String
    @Published public var activeBottomTabID: String

    private let store = LayoutPluginLocalStore.shared

    public init() {
        railVisible = store.loadRailVisible() ?? true
        bottomPanelVisible = store.loadBottomPanelVisible() ?? false
        bottomPanelHeight = CGFloat(store.loadEditorBottomPanelHeight() ?? 200)
        activeRailTabID = "explorer"
        activeBottomTabID = "editor-bottom-problems"
    }

    public func persistRailVisible() {
        store.saveRailVisible(railVisible)
    }

    public func persistBottomPanelVisible() {
        store.saveBottomPanelVisible(bottomPanelVisible)
    }

    public func persistBottomPanelHeight() {
        store.saveEditorBottomPanelHeight(Double(bottomPanelHeight))
    }
}
