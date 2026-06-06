import LumiUI
import SwiftUI

/// 智谱供应商标记（显示在自定义消息界面右上角）
struct ProviderBadge: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        Text(ZhipuProvider.shortName)
            .font(.appMicro)
            .fontWeight(.semibold)
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(theme.textSecondary.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(theme.textTertiary.opacity(0.25), lineWidth: 0.5)
            )
    }
}
