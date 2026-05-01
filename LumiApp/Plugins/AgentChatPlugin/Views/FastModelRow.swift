import AppKit
import MagicKit
import SwiftUI

/// TPS 较快模型单行视图，显示模型名、供应商标签和 TPS 速度
struct FastModelRow: View {
    /// 快模型条目
    let entry: FastModelEntry
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

                        Text(String(format: "%.1f t/s", entry.avgTPS))
                            .font(.caption2)
                            .foregroundColor(.green)

                        if let stat, stat.sampleCount > 0 {
                            sampleCountBadge(stat.sampleCount)
                        }
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

    /// 消息数量 badge
    private func sampleCountBadge(_ count: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 8, weight: .medium))
            Text("\(count)")
                .font(.caption2)
        }
        .foregroundColor(AppUI.Color.semantic.textSecondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(AppUI.Color.semantic.textSecondary.opacity(0.12))
        )
    }
}
