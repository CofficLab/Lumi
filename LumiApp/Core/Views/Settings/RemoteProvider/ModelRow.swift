import SwiftUI

/// 模型选择行组件 - 支持 hover 效果、选中/默认状态高亮和性能指标展示
struct ModelRow: View {
    let model: String
    let isDefault: Bool
    let isSelected: Bool
    var performanceStats: ModelPerformanceStats? = nil
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                modelHeader
                performanceIndicator
            }
            .padding(DesignTokens.Spacing.sm)
            .background(rowBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            .overlay(rowBorder)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("双击选择此模型")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var modelHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(model)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            
            Spacer()
            
            if isDefault {
                defaultBadge
            }
        }
    }
    
    @ViewBuilder
    private var defaultBadge: some View {
        Text("默认")
            .font(DesignTokens.Typography.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignTokens.Color.semantic.primary.opacity(0.15))
            )
            .foregroundColor(DesignTokens.Color.semantic.primary)
    }
    
    @ViewBuilder
    private var performanceIndicator: some View {
        if let stats = performanceStats, stats.avgTTFT > 0 {
            SettingsModelLatencyBar(
                ttft: stats.avgTTFT,
                totalLatency: stats.avgLatency,
                sampleCount: stats.sampleCount,
                tps: stats.avgTPS
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var rowBackgroundColor: Color {
        if isSelected {
            return DesignTokens.Color.semantic.primary.opacity(0.08)
        } else if isDefault {
            return DesignTokens.Color.semantic.primary.opacity(0.04)
        } else if isHovered {
            return Color.white.opacity(0.08)
        } else {
            return Color.white.opacity(0.05)
        }
    }
    
    @ViewBuilder
    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
            .stroke(borderColor, lineWidth: borderWidth)
    }
    
    private var borderColor: Color {
        if isSelected {
            return DesignTokens.Color.semantic.primary
        } else if isHovered {
            return DesignTokens.Color.semantic.primary.opacity(0.5)
        } else if isDefault {
            return DesignTokens.Color.semantic.primary.opacity(0.3)
        } else {
            return Color.white.opacity(0.1)
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 1.5 : 1
    }
    
    private var accessibilityLabel: String {
        var label = model
        if isDefault {
            label += "，默认模型"
        }
        if performanceStats != nil {
            label += "，有性能数据"
        }
        return label
    }
}