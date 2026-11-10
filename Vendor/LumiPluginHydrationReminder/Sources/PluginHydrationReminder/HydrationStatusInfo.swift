import SwiftUI
internal import Combine

struct HydrationReminderStatusInfo: View {
    @ObservedObject private var manager = HydrationReminderManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if manager.isActive {
                if let nextBreak = manager.nextBreakTime {
                    NextBreakCountdown(nextBreak: nextBreak)
                }
                HStack {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 9)).foregroundColor(.green)
                    Text(String(format: String(localized: "Today: %lld breaks", table: "HydrationReminder", bundle: .module), manager.todayBreakCount)).font(.system(size: 10)).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "zzz").font(.system(size: 9)).foregroundColor(.secondary)
                    Text("Break reminder is off", tableName: "HydrationReminder", bundle: .module).font(.system(size: 10)).foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

/// 「下一次休息」倒计时。
///
/// 只按分钟粒度刷新（60 秒一次），并且仅在提醒运行中、存在下一次休息时间时
/// 才被创建——避免 1 Hz 计时器在弹窗关闭后仍持续唤醒主线程。
private struct NextBreakCountdown: View {
    let nextBreak: Date

    @State private var now = Date()
    private let timer = Timer.publish(every: 60, tolerance: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        if nextBreak > now {
            let minutes = Int(nextBreak.timeIntervalSince(now)) / 60
            HStack {
                Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.secondary)
                Group {
                    if minutes < 1 {
                        Text("Next break: less than 1 min", tableName: "HydrationReminder", bundle: .module)
                    } else if minutes == 1 {
                        Text("Next break: 1 min", tableName: "HydrationReminder", bundle: .module)
                    } else {
                        Text(String(format: String(localized: "Next break: %lld mins", table: "HydrationReminder", bundle: .module), minutes))
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                Spacer()
            }
            .onReceive(timer) { _ in
                now = Date()
            }
        }
    }
}
