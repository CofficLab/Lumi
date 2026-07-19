import LumiKernel
import LumiUI
import SwiftUI

/// ChatSectionCoordinator 不可用时显示的错误按钮，点击弹出 popover 提示用户
struct ChatSectionCoordinatorErrorButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.appTitle)
                    .foregroundColor(.red)

                Text(LumiPluginLocalization.string("Service unavailable", bundle: .module))
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)

                Text(LumiPluginLocalization.string("Chat service is not available. Please restart the app.", bundle: .module))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }
            .padding(16)
        }
    }
}
