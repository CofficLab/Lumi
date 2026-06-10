import LumiUI
import SwiftUI

struct StopButton: View {
    @LumiTheme private var theme

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
