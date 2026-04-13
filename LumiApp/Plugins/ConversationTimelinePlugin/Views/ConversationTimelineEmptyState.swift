import MagicKit
import SwiftUI

/// 对话时间线空状态视图
struct ConversationTimelineEmptyState: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.5))

            Text("暂无消息")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }
}
