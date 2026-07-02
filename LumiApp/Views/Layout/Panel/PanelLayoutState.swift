import Foundation
import LumiCoreKit

@MainActor
final class PanelLayoutState: ObservableObject, LumiBottomPanelLayoutPresenting {
    @Published var activeRailTabID: String
    @Published var activeBottomTabID: String
    @Published private(set) var bottomPanelFocusGeneration = 0

    init() {
        activeRailTabID = "explorer"
        activeBottomTabID = "editor-bottom-problems"
    }

    func presentRailTab(id: String) {
        activeRailTabID = id
    }

    func presentBottomTab(id: String, viewContainerID: String) {
        activeBottomTabID = id
        bottomPanelFocusGeneration += 1
    }
}
