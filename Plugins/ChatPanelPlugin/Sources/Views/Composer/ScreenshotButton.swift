import LumiUI
import SwiftUI

struct ScreenshotButton: View {
    @LumiTheme private var theme
    @ObservedObject var screenshotState: ChatScreenshotState

    let canAttach: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if screenshotState.isPreparing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "crop")
                        .font(.system(size: ToolbarMetrics.iconSize, weight: ToolbarMetrics.iconWeight))
                }
            }
            .foregroundColor(theme.textSecondary)
            .frame(width: ToolbarMetrics.iconButtonSize, height: ToolbarMetrics.iconButtonSize)
            .background(theme.textPrimary.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canAttach || screenshotState.isCapturing)
        .keyboardShortcut("S", modifiers: [.command, .shift])
        .help(helpText)
    }

    private var helpText: String {
        if screenshotState.isPreparing {
            return "准备截图…"
        }
        return "区域截图 (⌘⇧S)"
    }
}
