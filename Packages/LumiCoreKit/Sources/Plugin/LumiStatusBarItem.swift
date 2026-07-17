import SwiftUI

@MainActor
public struct LumiStatusBarItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let placement: LumiStatusBarPlacement
    public let makeStatusBarView: (@MainActor () -> AnyView)?
    public let makePopoverView: @MainActor () -> AnyView

    public init<Popover: View>(
        id: String,
        title: String,
        systemImage: String,
        placement: LumiStatusBarPlacement = .trailing,
        @ViewBuilder popover: @escaping @MainActor () -> Popover
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.placement = placement
        self.makeStatusBarView = nil
        self.makePopoverView = { AnyView(popover()) }
    }

    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        placement: LumiStatusBarPlacement = .trailing,
        @ViewBuilder statusBarView: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.placement = placement
        self.makeStatusBarView = { AnyView(statusBarView()) }
        self.makePopoverView = { AnyView(EmptyView()) }
    }
}
