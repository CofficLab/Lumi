import LumiUI
import SwiftUI

/// 上下文用量圆环：中心显示当前模型的上下文窗口大小。
///
/// 圆环进度为「估算输入 / 输入预算」，颜色随占用比例升高而告警，
/// 与 toolbar 按钮的颜色口径保持一致。
struct ContextUsageRing: View {
    @LumiTheme private var theme

    /// 已使用的输入 token；`nil` 表示暂无用量数据，圆环只显示底环。
    let usedTokens: Int?
    /// 输入预算，作为圆环进度的分母。
    let limitTokens: Int
    /// 圆环中心文本，通常是模型的上下文窗口大小。
    let centerText: String

    private let diameter: CGFloat = 72
    private let lineWidth: CGFloat = 7
}

// MARK: - View

extension ContextUsageRing {
    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.divider, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: ratio)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: ratio)

            Text(centerText)
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, lineWidth + 2)
                .contentTransition(.numericText())
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

// MARK: - Computed Properties

extension ContextUsageRing {
    /// 输入占预算的比例，始终裁剪到 0...1。
    private var ratio: Double {
        guard let usedTokens, usedTokens > 0, limitTokens > 0 else { return 0 }
        return min(Double(usedTokens) / Double(limitTokens), 1)
    }

    private var tint: Color {
        guard let usedTokens, usedTokens > 0, limitTokens > 0 else { return theme.textSecondary }
        if ratio >= 0.9 { return .red }
        if ratio >= 0.75 { return theme.warning }
        return theme.primary
    }

    private var accessibilityText: String {
        let windowLabel = String(localized: "Context Window", defaultValue: "上下文窗口", bundle: .module)
        guard let usedTokens, usedTokens > 0, limitTokens > 0 else {
            return "\(windowLabel) \(centerText)"
        }
        let template = String(
            localized: "Estimated input: %@ tokens",
            defaultValue: "估算输入：%@ tokens",
            bundle: .module
        )
        return "\(windowLabel) \(centerText), \(String(format: template, usedTokens.formattedTokensShort))"
    }
}

// MARK: - Preview

#if DEBUG && os(macOS)
#Preview("Context Usage Ring - Normal") {
    ContextUsageRing(usedTokens: 32_000, limitTokens: 120_000, centerText: "128K")
        .padding()
}

#Preview("Context Usage Ring - Warning") {
    ContextUsageRing(usedTokens: 95_000, limitTokens: 120_000, centerText: "128K")
        .padding()
}

#Preview("Context Usage Ring - Critical") {
    ContextUsageRing(usedTokens: 118_000, limitTokens: 120_000, centerText: "128K")
        .padding()
}

#Preview("Context Usage Ring - No Usage") {
    ContextUsageRing(usedTokens: nil, limitTokens: 0, centerText: "未知")
        .padding()
}
#endif
