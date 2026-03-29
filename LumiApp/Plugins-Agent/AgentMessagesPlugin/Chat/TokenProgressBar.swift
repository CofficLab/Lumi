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
            AppDualSegmentBar(
                leadingRatio: inputRatio,
                leadingColor: .green,
                trailingColor: .purple
            )

            // Token 信息（一行显示）
            HStack(spacing: 8) {
                AppTag("\(inputTokens)", systemImage: "arrow.right.circle.fill")
                AppTag("\(outputTokens)", systemImage: "arrow.left.circle.fill")
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
