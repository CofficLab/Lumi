import AppKit
import MagicKit
import SwiftUI

/// 常用模型单行视图，显示模型名、供应商标签和性能信息
struct FrequentModelRow: View {
    /// 常用模型条目
    let entry: FrequentModelEntry
    /// 是否为当前选中模型
    let isSelected: Bool
    /// 详细性能统计
    let stat: ModelPerformanceStats?

    /// 点击选择回调
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.modelName)
                            .font(AppUI.Typography.body)
                            .lineLimit(1)

                        providerBadge(entry.providerDisplayName)

                        Spacer()

                        // 使用次数
                        Text("\(entry.useCount)")
                            .font(.caption2)
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                    if let stat, stat.avgTTFT > 0 {
                        ModelLatencyProgressBar(
                            ttft: stat.avgTTFT,
                            totalLatency: stat.avgLatency,
                            sampleCount: stat.sampleCount,
                            tps: stat.avgTPS
                        )
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(rowBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering && !isSelected {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Helper

    /// 行背景色
    private var rowBackground: some ShapeStyle {
        isSelected ? Color.accentColor.opacity(0.15) : Color.clear
    }

    /// 供应商标签
    private func providerBadge(_ name: String) -> some View {
        Text(name)
            .font(.caption2)
            .foregroundColor(AppUI.Color.semantic.textSecondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppUI.Color.semantic.textSecondary.opacity(0.12))
            )
    }
}
