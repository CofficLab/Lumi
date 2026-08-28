import LumiUI
import SwiftUI

/// 对话列表空状态视图
struct ListEmptyView: View {
    @LumiTheme private var theme: any LumiUITheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "message")
                .font(.appTitle)
                .foregroundColor(theme.textTertiary)

            Text("暂无对话")
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}
