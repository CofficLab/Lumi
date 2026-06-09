import SwiftUI

public struct EditorRailOutlineRegistration {
    public let tabID: String
    public let title: String
    public let systemImage: String
    public let makeView: @MainActor () -> AnyView

    public init(
        tabID: String,
        title: String,
        systemImage: String,
        makeView: @escaping @MainActor () -> AnyView
    ) {
        self.tabID = tabID
        self.title = title
        self.systemImage = systemImage
        self.makeView = makeView
    }
}
