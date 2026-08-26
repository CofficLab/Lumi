import LumiUI
import SwiftUI

struct SendButton: View {
    @LumiTheme private var theme

    let canSend: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: InputActionButtonMetrics.iconSize, weight: InputActionButtonMetrics.iconWeight))
                .foregroundColor(canSend ? .white : theme.textSecondary.opacity(0.28))
                .frame(width: InputActionButtonMetrics.iconButtonSize, height: InputActionButtonMetrics.iconButtonSize)
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
                .font(.system(size: InputActionButtonMetrics.iconSize, weight: InputActionButtonMetrics.iconWeight))
                .foregroundColor(.white)
                .frame(width: InputActionButtonMetrics.iconButtonSize, height: InputActionButtonMetrics.iconButtonSize)
                .background(Color.red.opacity(0.88), in: Circle())
        }
        .buttonStyle(.plain)
    }
}
