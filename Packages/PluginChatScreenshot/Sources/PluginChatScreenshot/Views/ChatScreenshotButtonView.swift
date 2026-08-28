import KernelCore
import LumiUI
import SwiftUI

/// 截图按钮：放在 ChatActionBar 中，点击启动区域截图流程。
///
/// 视觉风格：与 `ChatFileAttachmentButton` 协调的圆形图标按钮
/// （沿用旧版 `ChatScreenshotButtonView` 的外观）。
struct ChatScreenshotButtonView: View {
    @LumiTheme private var theme

    let kernel: KernelCoreContainer

    @State private var isPreparing = false

    var body: some View {
        Button {
            start()
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
        .help(LumiPluginLocalization.string("Capture screenshot", bundle: .module))
    }

    private func start() {
        guard !isPreparing else { return }
        isPreparing = true
        Task { @MainActor in
            await ScreenshotFlowRunner.run(kernel: kernel)
            isPreparing = false
        }
    }
}
