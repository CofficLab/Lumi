import LumiUI
import SwiftUI

struct ToolbarButton: View {
    @LumiTheme private var theme

    let systemImage: String
    let help: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: ToolbarMetrics.iconSize, weight: ToolbarMetrics.iconWeight))
                .foregroundColor(theme.textSecondary.opacity(isEnabled ? 1 : 0.35))
                .frame(width: ToolbarMetrics.iconButtonSize, height: ToolbarMetrics.iconButtonSize)
                .background(theme.textPrimary.opacity(isEnabled ? 0.07 : 0.03), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(help)
    }
}

struct SendButton: View {
    @LumiTheme private var theme

    let canSend: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: ToolbarMetrics.iconSize, weight: ToolbarMetrics.iconWeight))
                .foregroundColor(canSend ? .white : theme.textSecondary.opacity(0.28))
                .frame(width: ToolbarMetrics.iconButtonSize, height: ToolbarMetrics.iconButtonSize)
                .background(sendBackground, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
    }

    private var sendBackground: Color {
        canSend ? theme.primary : theme.textPrimary.opacity(0.05)
    }
}

struct StopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "stop.fill")
                .font(.system(size: ToolbarMetrics.iconSize, weight: ToolbarMetrics.iconWeight))
                .foregroundColor(.white)
                .frame(width: ToolbarMetrics.iconButtonSize, height: ToolbarMetrics.iconButtonSize)
                .background(Color.red.opacity(0.88), in: Circle())
        }
        .buttonStyle(.plain)
    }
}
