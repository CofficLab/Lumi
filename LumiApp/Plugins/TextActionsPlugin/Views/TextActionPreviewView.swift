import SwiftUI

/// 显示文本选择菜单的实时预览效果。
struct TextActionPreviewView: View {
    let isEnabled: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            ZStack {
                // Document background
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.Material.glass)
                    .frame(width: 220, height: 160)

                // Mock content
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                        .frame(width: 180, height: 8)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                        .frame(width: 160, height: 8)

                    HStack(spacing: 0) {
                        Text("Select ")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                        Text("this text")
                            .font(.system(size: 12))
                            .padding(.horizontal, 2)
                            .background(isEnabled ? DesignTokens.Color.semantic.primary.opacity(0.3) : SwiftUI.Color.clear)
                            .foregroundColor(isEnabled ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textSecondary)
                            .overlay(
                                GeometryReader { _ in
                                    if isEnabled {
                                        MockActionMenu()
                                            .offset(x: -20, y: -60)
                                    }
                                }
                            )

                        Text(" to see.")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }

                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                        .frame(width: 140, height: 8)
                }
            }
        }
        .padding()
    }
}

// MARK: - 模拟菜单视图

struct MockActionMenu: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TextActionType.allCases) { action in
                VStack(spacing: 4) {
                    Image(systemName: action.icon)
                        .font(.system(size: 14))
                    Text(action.title)
                        .font(.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }
                .frame(width: 44, height: 44)
                .background(DesignTokens.Material.glass)
                .cornerRadius(DesignTokens.Radius.sm)
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background(DesignTokens.Material.glass)
        .cornerRadius(DesignTokens.Radius.md)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .withNavigation(TextActionsPlugin.id)
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
