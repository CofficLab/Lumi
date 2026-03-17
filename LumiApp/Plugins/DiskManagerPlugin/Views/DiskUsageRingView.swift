import SwiftUI

/// 磁盘使用率环形视图
struct DiskUsageRingView: View {
    let percentage: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.2), lineWidth: 10)

            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [DesignTokens.Color.semantic.info, DesignTokens.Color.semantic.primary]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * percentage)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack {
                Text("\(Int(percentage * 100))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text("已用")
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        }
    }
}
