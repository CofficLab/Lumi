import SwiftUI

/// 时间状态视图：在状态栏显示当前时间
struct TimeStatusView: View {
    /// 当前时间
    @State private var currentDate = Date()

    /// 计时器
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// 日期格式化器
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 4) {
            Text(timeFormatter.string(from: currentDate))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Text(dateFormatter.string(from: currentDate))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }
}

// MARK: - Preview

#Preview("Time Status View") {
    HStack {
        Spacer()
        TimeStatusView()
            .padding()
        Spacer()
    }
    .frame(width: 200, height: 40)
    .background(Color(.controlBackgroundColor))
}
