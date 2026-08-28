import SwiftUI

/// A section contributed by a plugin to the detail pane of a project setting.
@MainActor
public struct ProjectDetailSectionItem: Identifiable {
    public let id: String
    public let order: Int
    public let makeView: @MainActor (String) -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 200,
        @ViewBuilder view: @escaping @MainActor (String) -> Content
    ) {
        self.id = id
        self.order = order
        self.makeView = { path in AnyView(view(path)) }
    }
}
