import Foundation

struct LayoutState {
    var activeViewContainerID: String?

    mutating func activateViewContainer(id: String) {
        activeViewContainerID = id
    }
}
