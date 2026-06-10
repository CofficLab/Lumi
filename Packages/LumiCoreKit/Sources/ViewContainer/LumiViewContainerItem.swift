import SwiftUI

@MainActor
public struct LumiViewContainerItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let showsChatSection: Bool
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        showsChatSection: Bool = false,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.showsChatSection = showsChatSection
        self.makeView = { AnyView(content()) }
    }
}
