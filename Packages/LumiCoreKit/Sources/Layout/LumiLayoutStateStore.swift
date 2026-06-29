import Combine
import Foundation

@MainActor
public final class LumiLayoutStateStore: ObservableObject {
    public static let shared = LumiLayoutStateStore()

    @Published public var activeViewContainerID: String?
    @Published public var chatSectionVisible: Bool = true
    @Published public var bottomPanelVisible: Bool = true

    public func activateViewContainer(id: String) {
        activeViewContainerID = id
    }
}
