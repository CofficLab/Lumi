import SwiftUI

/// 磁盘使用率环形视图
struct DiskUsageRingView: View {
    @StateObject private var viewModel = DiskManagerViewModel()

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppUI.Color.semantic.textTertiary.opacity(0.2), lineWidth: 10)

            if let usage = viewModel.diskUsage {
                Circle()
                    .trim(from: 0, to: usage.usedPercentage)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [AppUI.Color.semantic.info, AppUI.Color.semantic.primary]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * usage.usedPercentage)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack {
                if let usage = viewModel.diskUsage {
                    Text("\(Int(usage.usedPercentage * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                    Text("已用")
                        .font(.caption2)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .onAppear {
            viewModel.refreshDiskUsage()
        }
    }
}

// MARK: - 预览

#Preview {
    DiskUsageRingView()
}
