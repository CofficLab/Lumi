import SwiftUI
internal import Combine

struct HydrationReminderStatusInfo: View {
    @ObservedObject private var manager = HydrationReminderManager.shared
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if manager.isActive {
                if let nextBreak = manager.nextBreakTime {
                    let timeUntil = nextBreak.timeIntervalSince(currentTime)
                    if timeUntil > 0 {
                        HStack {
                            Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.secondary)
                            let minutes = Int(timeUntil) / 60
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
                    }
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
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
}
