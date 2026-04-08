import Foundation
import SwiftUI

struct TerminalTabItem: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(isSelected ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textSecondary)

            if isHovered || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(
                            isHovered
                                ? AppUI.Color.semantic.textSecondary
                                : AppUI.Color.semantic.textTertiary
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundShape)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
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
