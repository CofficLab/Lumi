import SwiftUI

/// Placeholder for the Chat view container body.
/// Conversation list lives in the rail; messages and composer live in the chat section.
public struct ChatPanelEmptyView: View {
    public init() {}

    public var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
