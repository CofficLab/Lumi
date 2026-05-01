import SwiftUI

// MARK: - 玻璃分割线
///
/// 玻璃态分割线，微妙的内容分隔。
///
struct GlassDivider: View {
    var thickness: CGFloat = 1
    var opacity: Double = 0.1

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        SwiftUI.Color.clear,
                        SwiftUI.Color.white.opacity(opacity),
                        SwiftUI.Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: thickness)
    }
}

// MARK: - 预览
#Preview("玻璃分割线") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        Text("内容上方")
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

        GlassDivider()

        Text("内容下方")
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

        GlassDivider(thickness: 2, opacity: 0.2)

        Text("更粗的分割线下方")
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(width: 300)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
