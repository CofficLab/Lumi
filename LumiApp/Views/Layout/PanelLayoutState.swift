import Foundation
import LayoutPlugin
import LumiCoreKit

@MainActor
final class PanelLayoutState: ObservableObject, LumiBottomPanelLayoutPresenting {
    @Published var activeRailTabID: String
    @Published var activeBottomTabID: String

    private let store = LayoutPluginLocalStore.shared

    init() {
        activeRailTabID = store.loadSelectedRailTabID() ?? "explorer"
        activeBottomTabID = "editor-bottom-problems"
    }

    func persistActiveRailTabID() {
        store.saveSelectedRailTabID(activeRailTabID)
    }

    func presentRailTab(id: String) {
        activeRailTabID = id
        persistActiveRailTabID()
    }

    func presentBottomTab(id: String) {
        activeBottomTabID = id
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
