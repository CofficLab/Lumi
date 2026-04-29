import SwiftUI

// MARK: - 玻璃键值对行
///
/// 用于显示标签-值对的信息行
///
struct GlassKeyValueRow: View {
    // MARK: - 配置
    var label: String
    var value: String
    var labelWidth: CGFloat = 100
    var isValueSelectable: Bool = true
    var valueColor: Color? = nil

    // MARK: - 主体
    var body: some View {
        HStack(alignment: .top) {
            // 标签
            Text(label)
                .font(DesignTokens.Typography.subheadline)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: labelWidth, alignment: .leading)

            // 分隔符
            Text(":")
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            // 值
            if isValueSelectable {
                Text(value)
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(valueColor ?? DesignTokens.Color.semantic.textPrimary)
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(valueColor ?? DesignTokens.Color.semantic.textPrimary)
            }

            Spacer()
        }
    }
}

// MARK: - 便捷初始化
extension GlassKeyValueRow {
    /// 创建键值对行，使用默认配置
    static func row(_ label: String, value: String) -> some View {
        GlassKeyValueRow(label: label, value: value)
    }

    /// 创建可选择值的键值对行
    static func selectable(_ label: String, value: String) -> some View {
        GlassKeyValueRow(label: label, value: value, isValueSelectable: true)
    }
}

// MARK: - 预览
#Preview("键值对行") {
    GlassCard {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            GlassKeyValueRow(label: "App Name", value: "Lumi")
            GlassKeyValueRow(label: "Version", value: "1.0.0")
            GlassKeyValueRow(label: "Build", value: "123", isValueSelectable: false)
            GlassKeyValueRow(label: "Bundle ID", value: "com.lumi.app", valueColor: .blue)

            GlassDivider()

            GlassKeyValueRow.row("OS", value: "macOS 15.0")
            GlassKeyValueRow.selectable("Architecture", value: "arm64")
        }
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(width: 400)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
