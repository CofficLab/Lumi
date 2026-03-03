import SwiftUI

/// 深度警告横幅组件
struct DepthWarningBanner: View {
    let warning: DepthWarning
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: warningIcon)
                .font(.system(size: 16))
                .foregroundColor(warning.iconColor)
                .frame(width: 20)

            // 消息文本
            Text(warning.warningMessage)
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .lineLimit(2)

            Spacer()

            // 进度指示器
            DepthProgressIndicator(warning: warning)

            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(warningBackground)
        .overlay(
            Rectangle()
                .frame(width: 4)
                .foregroundColor(warning.iconColor),
            alignment: .leading
        )
    }

    private var warningIcon: String {
        switch warning.warningType {
        case .approaching:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        case .reached:
            return "xmark.octagon.fill"
        }
    }

    private var warningBackground: some View {
        Group {
            if warning.warningType == .reached {
                Color.red.opacity(0.15)
            } else {
                Color.orange.opacity(0.12)
            }
        }
    }
}

/// 深度进度指示器组件
private struct DepthProgressIndicator: View {
    let warning: DepthWarning

    var body: some View {
        HStack(spacing: 4) {
            Text("\(warning.currentDepth)/\(warning.maxDepth)")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .monospacedDigit()

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.3))
                        .frame(height: 4)

                    // 进度
                    RoundedRectangle(cornerRadius: 2)
                        .fill(warning.iconColor)
                        .frame(width: geometry.size.width * warning.percentage, height: 4)
                }
            }
            .frame(width: 60, height: 4)
        }
    }
}

// MARK: - Preview

#Preview("Approaching Warning") {
    VStack(spacing: 20) {
        DepthWarningBanner(
            warning: DepthWarning(currentDepth: 7, maxDepth: 10, warningType: .approaching),
            onDismiss: {}
        )

        DepthWarningBanner(
            warning: DepthWarning(currentDepth: 9, maxDepth: 10, warningType: .critical),
            onDismiss: {}
        )

        DepthWarningBanner(
            warning: DepthWarning(currentDepth: 10, maxDepth: 10, warningType: .reached),
            onDismiss: {}
        )
    }
    .padding()
    .frame(width: 600)
    .background(Color.black)
}

