/// 详细信息页面（点击状态栏后展开的详细内容）
struct DeviceInfoDetailView: View {
    @StateObject private var viewModel = SystemMonitorViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 内存使用
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.system(size: 11))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)

                Spacer()

                Text(viewModel.metrics.memoryUsage.description)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            }

            // 内存进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppUI.Color.semantic.textTertiary.opacity(0.15))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppUI.Color.semantic.info.opacity(0.7))
                        .frame(width: geometry.size.width * CGFloat(viewModel.metrics.memoryUsage.percentage))
                }
            }
            .frame(height: 4)

            Divider()

            // 网络
            HStack {
                Label("Network", systemImage: "network")
                    .font(.system(size: 11))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)

                Spacer()

                Text("↓\(viewModel.metrics.network.downloadSpeedString)")
                    .font(.system(size: 10))
                    .monospacedDigit()

                Text("↑\(viewModel.metrics.network.uploadSpeedString)")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
        }
        .padding()
        .onAppear {
            viewModel.startMonitoring()
        }
    }
}