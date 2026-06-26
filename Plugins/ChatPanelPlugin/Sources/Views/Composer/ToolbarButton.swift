import LumiUI
import SwiftUI

struct ToolbarButton: View {
    @LumiTheme private var theme

    let systemImage: String
    let help: String
    var isEnabled: Bool = true
    let action: () -> Void
    var onDisabledTap: (() -> Void)? = nil

    var body: some View {
        Button {
            if isEnabled {
                action()
            } else {
                onDisabledTap?()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: ToolbarMetrics.iconSize, weight: ToolbarMetrics.iconWeight))
                .foregroundColor(theme.textSecondary.opacity(isEnabled ? 1 : 0.35))
                .frame(width: ToolbarMetrics.iconButtonSize, height: ToolbarMetrics.iconButtonSize)
                .background(theme.textPrimary.opacity(isEnabled ? 0.07 : 0.03), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
