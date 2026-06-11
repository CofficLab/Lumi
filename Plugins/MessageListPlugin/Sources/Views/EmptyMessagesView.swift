import LumiUI
import SwiftUI
import LumiCoreKit

public struct EmptyMessagesView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public init() {}

    public var body: some View {
        AppEmptyState(
            icon: "bubble.left.and.bubble.right",
            title: LumiPluginLocalization.string("No messages yet", bundle: .module)
        )
        .foregroundColor(theme.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
