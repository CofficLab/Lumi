import SwiftUI

struct TerminalTabItem: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundColor(isSelected ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(backgroundShape)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
            .contextMenu {
                Button(action: onClose) {
                    Label("Close Tab", systemImage: "xmark")
                }
            }
    }

    @ViewBuilder
    var backgroundShape: some View {
        if isSelected {
            Color.clear
                .appSurface(style: .glass, cornerRadius: AppUI.Radius.sm)
        } else {
            Color.clear
        }
    }
}
