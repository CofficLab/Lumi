import SwiftUI

/// App 模式下未选择导航时的空状态提示
struct NavigationEmptyGuideView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Color.adaptive.textSecondary(for: colorScheme))

            Text("选择一项开始使用")
                .font(.headline)
                .foregroundColor(DesignTokens.Color.adaptive.textSecondary(for: colorScheme))

            Text("请从左侧栏选择一个功能")
                .font(.caption)
                .foregroundColor(DesignTokens.Color.adaptive.textTertiary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
