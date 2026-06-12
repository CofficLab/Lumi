import LumiUI
import SwiftUI
import LumiCoreKit

public struct EmptyStateView: View {
    public init() {}

    public var body: some View {
        AppEmptyState(
            icon: "text.bubble",
            title: LumiPluginLocalization.string("Select or start a conversation", bundle: .module)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
