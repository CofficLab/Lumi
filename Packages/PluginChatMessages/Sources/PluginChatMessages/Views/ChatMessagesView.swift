import LumiCoreKit
import LumiUI
import SwiftUI

public struct ChatMessagesView: View {
    public init() {}

    public var body: some View {
        Group {
            if !ChatMessagesRuntime.hasConversation {
                EmptyStateView()
            } else if ChatMessagesRuntime.messages.isEmpty {
                EmptyMessagesView()
            } else {
                MessageListView()
            }
        }
    }
}
