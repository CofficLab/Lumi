import Foundation
import LumiCoreKit

@MainActor
final class PanelLayoutState: ObservableObject, LumiBottomPanelLayoutPresenting {
    @Published var activeRailTabID: String
    @Published var activeBottomTabID: String
    @Published private(set) var bottomPanelFocusGeneration = 0

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

    func presentBottomTab(id: String, viewContainerID: String) {
        activeBottomTabID = id
        bottomPanelFocusGeneration += 1

        let storageKey = LayoutStorageKey.bottomPanelHeight(viewContainerID: viewContainerID)
        let savedHeight = store.loadSplitDimension(forKey: storageKey) ?? 0
        let defaultHeight = Double(SplitDimensionConstraints.bottomPanel.defaultSize)
        if savedHeight < defaultHeight {
            store.saveSplitDimension(defaultHeight, forKey: storageKey)
        }
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
