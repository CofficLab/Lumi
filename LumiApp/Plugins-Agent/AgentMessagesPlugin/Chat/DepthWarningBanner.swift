import SwiftUI

/// 深度警告横幅组件
public struct DepthWarningBanner: View {
    @EnvironmentObject var depthWarningViewModel: DepthWarningVM

    public var body: some View {
        if let warning = depthWarningViewModel.depthWarning {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: warningIcon(for: warning))
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
                Button(action: {
                    depthWarningViewModel.dismissDepthWarning()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(warningBackground(for: warning))
            .overlay(
                Rectangle()
                    .frame(width: 4)
                    .foregroundColor(warning.iconColor),
                alignment: .leading
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("深度提醒")
            .accessibilityHint(warning.warningMessage)
        }
    }

    private func warningIcon(for warning: DepthWarning) -> String {
        switch warning.warningType {
        case .approaching:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        case .reached:
            return "xmark.octagon.fill"
        }
    }

    private func warningBackground(for warning: DepthWarning) -> some View {
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
            // GeometryReader { geometry in
            //     ZStack(alignment: .leading) {
            //         // 背景条
            //         RoundedRectangle(cornerRadius: 2)
            //             .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.3))
            //             .frame(height: 4)

            //         // 进度
            //         RoundedRectangle(cornerRadius: 2)
            //             .fill(warning.iconColor)
            //             .frame(width: geometry.size.width * warning.percentage, height: 4)
            //     }
            // }
            // .frame(width: 60, height: 4)
        }
    }
}
