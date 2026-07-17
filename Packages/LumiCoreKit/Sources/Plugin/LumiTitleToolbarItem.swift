import SwiftUI

@MainActor
public struct LumiTitleToolbarItem: Identifiable {
    public let id: String
    public let title: String
    public let placement: LumiTitleToolbarPlacement
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        placement: LumiTitleToolbarPlacement = .trailing,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.placement = placement
        self.makeView = { AnyView(content()) }
    }
}
