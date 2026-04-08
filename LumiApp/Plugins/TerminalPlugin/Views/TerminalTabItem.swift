import Foundation
import SwiftUI

struct TerminalTabItem: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(isSelected ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textSecondary)

            if isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundShape)
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
