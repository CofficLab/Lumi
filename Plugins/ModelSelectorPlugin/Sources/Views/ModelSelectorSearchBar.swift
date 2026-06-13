import LumiUI
import SwiftUI

struct ModelSelectorSearchBar: View {
    @LumiTheme private var theme

    @Binding var searchText: String
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppSearchBar(text: $searchText, placeholder: "Search models or providers...")

            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(.appCallout)
                .foregroundColor(theme.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.background)
    }
}
