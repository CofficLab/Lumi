import SwiftUI
import DiskManagerKit

/// 磁盘使用率环形视图
struct DiskUsageRingView: View {
    @StateObject private var viewModel = DiskManagerViewModel()

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "98989E").opacity(0.2), lineWidth: 10)

            if let usage = viewModel.diskUsage {
                Circle()
                    .trim(from: 0, to: usage.usedPercentage)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Color(hex: "0A84FF"), Color(hex: "7C6FFF")]),
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
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    Text("已用")
                        .font(.caption2)
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
