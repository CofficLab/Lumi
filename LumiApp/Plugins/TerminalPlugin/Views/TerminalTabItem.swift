import SwiftUI
import LumiUI

struct TerminalTabItem: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundColor(isSelected ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(backgroundShape)
            .onTapGesture {
                onSelect()
            }
            .contextMenu {
                Button(action: onClose) {
                    Label(String(localized: "Close Tab", table: "Terminal"), systemImage: "xmark")
                }
            }
    }

    @ViewBuilder
    var backgroundShape: some View {
        if isSelected {
            Color.clear
                .appSurface(style: .glassUltraThick, cornerRadius: 8)
        } else {
            Color.clear
        }
    }
}
