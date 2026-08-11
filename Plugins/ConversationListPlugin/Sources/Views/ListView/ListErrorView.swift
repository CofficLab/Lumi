import LumiUI
import SwiftUI

/// 对话列表错误视图
///
/// 当 `kernel.conversations` 服务不可用时展示，提示用户会话服务未就绪。
struct ListErrorView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let reason: String?

    init(reason: String? = nil) {
        self.reason = reason
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.appTitle)
                .foregroundColor(theme.error.opacity(0.7))

            Text(LumiPluginLocalization.string("Unable to load conversations", bundle: .module))
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)

            if let reason {
                Text(reason)
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}
