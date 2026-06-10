import Foundation
import LayoutPlugin

@MainActor
final class PanelLayoutState: ObservableObject {
    @Published var bottomPanelHeight: CGFloat
    @Published var activeRailTabID: String
    @Published var activeBottomTabID: String

    private let store = LayoutPluginLocalStore.shared

    init() {
        bottomPanelHeight = CGFloat(store.loadEditorBottomPanelHeight() ?? 200)
        activeRailTabID = store.loadSelectedRailTabID() ?? "explorer"
        activeBottomTabID = "editor-bottom-problems"
    }

    func persistBottomPanelHeight() {
        store.saveEditorBottomPanelHeight(Double(bottomPanelHeight))
    }

    func persistActiveRailTabID() {
        store.saveSelectedRailTabID(activeRailTabID)
    }

    func presentRailTab(id: String) {
        activeRailTabID = id
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
