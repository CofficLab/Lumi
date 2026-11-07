import SwiftUI

@MainActor
public struct MenuBarContribution: Identifiable {
    public let id: String
    public let title: String
    public let order: Int
    public let ownerPluginID: String
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        order: Int = 200,
        ownerPluginID: String,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.ownerPluginID = ownerPluginID
        self.makeView = { AnyView(content()) }
    }
}
