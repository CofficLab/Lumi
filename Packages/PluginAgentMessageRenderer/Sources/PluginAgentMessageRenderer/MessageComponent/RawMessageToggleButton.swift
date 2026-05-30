import SwiftUI
import LumiUI

public struct RawMessageToggleButton: View {
    @Binding var showRawMessage: Bool

    public init(showRawMessage: Binding<Bool>) {
        _showRawMessage = showRawMessage
    }

    public var body: some View {
        AppIconButton(
            systemImage: showRawMessage ? "text.bubble.fill" : "curlybraces",
            size: .compact,
            isActive: showRawMessage
        ) {
            showRawMessage.toggle()
        }
        .help(showRawMessage ? "Show formatted message" : "Show raw message")
    }
}
