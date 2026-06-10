import LumiUI
import SwiftUI

struct ToolbarButton: View {
    @LumiTheme private var theme

    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: ToolbarMetrics.iconSize, weight: ToolbarMetrics.iconWeight))
                .foregroundColor(theme.textSecondary)
                .frame(width: ToolbarMetrics.iconButtonSize, height: ToolbarMetrics.iconButtonSize)
                .background(theme.textPrimary.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
