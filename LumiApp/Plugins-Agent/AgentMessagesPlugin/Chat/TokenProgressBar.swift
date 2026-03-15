import SwiftUI

// MARK: - Token Progress Bar

/// Token 进度条组件
/// 可视化显示输入和输出 token 数量
struct TokenProgressBar: View {
    /// 输入 token 数量
    let inputTokens: Int
    /// 输出 token 数量
    let outputTokens: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 进度条 - 使用固定尺寸的 ZStack 替代 GeometryReader
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 4)

                // 输入 token 部分（绿色）
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 120 * inputRatio, height: 4)

                    Spacer(minLength: 0)
                }

                // 输出 token 部分（紫色）
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: 120 * (1 - inputRatio), height: 4)
                }
            }
            .frame(width: 120, height: 4)

            // Token 信息（一行显示）
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 7, weight: .medium))
                    Text("\(inputTokens)")
                        .font(DesignTokens.Typography.caption2)
                        .fixedSize()
                }
                .foregroundColor(.green)

                HStack(spacing: 2) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 7, weight: .medium))
                    Text("\(outputTokens)")
                        .font(DesignTokens.Typography.caption2)
                        .fixedSize()
                }
                .foregroundColor(.purple)
            }
        }
        .fixedSize()
        .help(helpText)
    }

    // MARK: - Computed Properties

    /// 输入 token 占总 token 的比例
    private var inputRatio: Double {
        let total = inputTokens + outputTokens
        guard total > 0 else { return 0 }
        return Double(inputTokens) / Double(total)
    }

    // MARK: - Helper Methods

    /// 帮助文本
    private var helpText: String {
        let inputPercent = String(format: "%.1f", inputRatio * 100)
        let outputPercent = String(format: "%.1f", (1 - inputRatio) * 100)
        return """
        ➡️ 输入 Token: \(inputTokens) (\(inputPercent)%)
        ⬅️ 输出 Token: \(outputTokens) (\(outputPercent)%)

        输入 Token 表示发送给模型的 token 数量
        输出 Token 表示模型生成的 token 数量
        """
    }
}
