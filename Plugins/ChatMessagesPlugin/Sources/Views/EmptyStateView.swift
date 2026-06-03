import LumiUI
import SwiftUI

public struct EmptyStateView: View {
    public init() {}

    public var body: some View {
        AppEmptyState(
            icon: "text.bubble",
            title: String(localized: "Select or start a conversation")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
