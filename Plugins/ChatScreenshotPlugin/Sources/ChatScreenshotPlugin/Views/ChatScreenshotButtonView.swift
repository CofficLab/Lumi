import LumiKernel
import LumiUI
import SwiftUI

/// 截图按钮:放在 ChatActionBar 中,点击 post `.lumiCaptureScreenshot` 通知
///
/// 视觉风格:与 `ConversationInputPlugin.SendButtonView` 协调的圆形图标按钮
struct ChatScreenshotButtonView: View {
    @ObservedObject var kernel: LumiKernel
    @State private var isPreparing = false
    @LumiTheme private var theme

    var body: some View {
        Button {
            trigger()
        } label: {
            Group {
                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundColor(theme.textSecondary)
            .frame(width: 28, height: 28)
            .background(theme.textPrimary.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isPreparing)
        .help(String(localized: "Capture screenshot (⌘⇧S)", bundle: .module))
    }

    private func trigger() {
        NotificationCenter.default.post(name: .lumiCaptureScreenshot, object: nil)
    }
}