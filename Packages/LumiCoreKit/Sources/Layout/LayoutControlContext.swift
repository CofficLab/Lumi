import SwiftUI

public struct LayoutControlContext {
    public var chatSectionVisible: Binding<Bool>
    public var bottomPanelVisible: Binding<Bool>

    public init(chatSectionVisible: Binding<Bool>, bottomPanelVisible: Binding<Bool>) {
        self.chatSectionVisible = chatSectionVisible
        self.bottomPanelVisible = bottomPanelVisible
    }
}
