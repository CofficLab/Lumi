import MagicKit
import SwiftUI

// MARK: - Browse Row View

struct BrowseRowView: View {
    @Binding var isFileImporterPresented: Bool
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            isFileImporterPresented = true
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)

                Text(String(localized: "Select New Project", table: "RecentProjects"))
                    .font(AppUI.Typography.body)
                    .foregroundColor(.accentColor)

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: DesignTokens.Duration.micro)) {
                isHovered = hovering
            }
        }
    }
}
