import LumiUI
import SwiftUI

public struct EmptyMessagesView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public init() {}

    public var body: some View {
        AppEmptyState(
            icon: "bubble.left.and.bubble.right",
            title: String(localized: "No messages yet", table: "AgentChat")
        )
        .foregroundColor(theme.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
