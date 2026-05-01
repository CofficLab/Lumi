import SwiftUI

/// 双段进度条组件（用于时延/Token 占比等）。
struct AppDualSegmentBar: View {
    let leadingRatio: Double
    let leadingColor: Color
    let trailingColor: Color
    let width: CGFloat
    let height: CGFloat

    init(
        leadingRatio: Double,
        leadingColor: Color,
        trailingColor: Color,
        width: CGFloat = 120,
        height: CGFloat = 4
    ) {
        self.leadingRatio = min(max(leadingRatio, 0), 1)
        self.leadingColor = leadingColor
        self.trailingColor = trailingColor
        self.width = width
        self.height = height
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: height / 2)
                .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.18))
                .frame(width: width, height: height)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(leadingColor)
                    .frame(width: width * leadingRatio, height: height)
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(trailingColor)
                    .frame(width: width * (1 - leadingRatio), height: height)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 10) {
        AppDualSegmentBar(leadingRatio: 0.3, leadingColor: .orange, trailingColor: .blue)
        AppDualSegmentBar(leadingRatio: 0.65, leadingColor: .green, trailingColor: .purple)
    }
    .padding()
    .inRootView()
}
