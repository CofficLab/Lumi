import Foundation
import SwiftUI

@MainActor
public struct ModelSelectorSidebarItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}
