import Foundation

/// Presents a plugin-contributed bottom panel tab in the app layout.
@MainActor
public protocol LumiBottomPanelLayoutPresenting: AnyObject {
    func presentBottomTab(id: String, viewContainerID: String)
}
