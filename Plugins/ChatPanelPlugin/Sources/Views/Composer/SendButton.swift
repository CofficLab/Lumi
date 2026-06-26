import LumiUI
import SwiftUI

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
