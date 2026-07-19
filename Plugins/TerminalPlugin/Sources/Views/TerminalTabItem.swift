import SwiftUI
import LumiUI
import LumiKernel

public struct TerminalTabItem: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let title: String
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onClose: () -> Void

    public var body: some View {
        Text(title)
            .font(.appCaption)
            .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
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
                    Label(LumiPluginLocalization.string("Close Tab", bundle: .module), systemImage: "xmark")
                }
            }
    }

    @ViewBuilder
    public var backgroundShape: some View {
        if isSelected {
            Color.clear
                .appSurface(style: .glassUltraThick, cornerRadius: 8)
        } else {
            Color.clear
        }
    }
}
