import SwiftUI

public struct LayoutControlContext {
    public var chatSectionVisible: Binding<Bool>

    public init(chatSectionVisible: Binding<Bool>) {
        self.chatSectionVisible = chatSectionVisible
    }
}
