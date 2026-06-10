import Foundation
import LayoutPlugin

@MainActor
final class PanelLayoutState: ObservableObject {
    @Published var railVisible: Bool
    @Published var bottomPanelVisible: Bool
    @Published var bottomPanelHeight: CGFloat
    @Published var activeRailTabID: String
    @Published var activeBottomTabID: String

    private let store = LayoutPluginLocalStore.shared

    init() {
        railVisible = store.loadRailVisible() ?? true
        bottomPanelVisible = store.loadBottomPanelVisible() ?? false
        bottomPanelHeight = CGFloat(store.loadEditorBottomPanelHeight() ?? 200)
        activeRailTabID = store.loadSelectedRailTabID() ?? "explorer"
        activeBottomTabID = "editor-bottom-problems"
    }

    func persistRailVisible() {
        store.saveRailVisible(railVisible)
    }

    func persistBottomPanelVisible() {
        store.saveBottomPanelVisible(bottomPanelVisible)
    }

    func persistBottomPanelHeight() {
        store.saveEditorBottomPanelHeight(Double(bottomPanelHeight))
    }

    func persistActiveRailTabID() {
        store.saveSelectedRailTabID(activeRailTabID)
    }

    func presentRailTab(id: String) {
        railVisible = true
        activeRailTabID = id
        persistRailVisible()
        persistActiveRailTabID()
    }
}

private extension LayoutPluginLocalStore {
    func loadSelectedRailTabID() -> String? {
        object(forKey: "Split.Rail.SelectedTab") as? String
    }

    func saveSelectedRailTabID(_ tabID: String) {
        set(tabID, forKey: "Split.Rail.SelectedTab")
    }
}
