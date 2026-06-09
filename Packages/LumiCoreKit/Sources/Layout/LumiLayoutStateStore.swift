import Combine
import Foundation

@MainActor
public final class LumiLayoutStateStore: ObservableObject {
    public static let shared = LumiLayoutStateStore()

    @Published public var activeViewContainerID: String?

    public func activateViewContainer(id: String) {
        activeViewContainerID = id
    }
}
