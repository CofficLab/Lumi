import SwiftUI

struct HydrationIntervalPicker: View {
    @ObservedObject private var manager = HydrationReminderManager.shared

    var body: some View {
        // 弹窗宽度固定（300pt），自定义间隔多时按钮会溢出，
        // 因此用横向滚动承载完整列表。
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(manager.availableIntervals) { interval in
                        HydrationIntervalButton(
                            interval: interval,
                            isSelected: manager.selectedInterval == interval.timeInterval
                        ) {
                            manager.updateInterval(interval.timeInterval)
                        }
                        .id(interval.id)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
            }
            .onChange(of: manager.selectedInterval) { newValue in
                // 选中的自定义间隔可能在可视区之外，滚动到可见处，
                // 否则用户会看不到自己选中了什么。
                let target = manager.availableIntervals.first { $0.timeInterval == newValue }
                if let target {
                    withAnimation { proxy.scrollTo(target.id, anchor: .center) }
                }
            }
            .onAppear {
                let target = manager.availableIntervals.first { $0.timeInterval == manager.selectedInterval }
                if let target {
                    proxy.scrollTo(target.id, anchor: .center)
                }
            }
        }
    }
}

private struct HydrationIntervalButton: View {
    let interval: HydrationReminderManager.IntervalOption
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false
    var body: some View {
        Button(action: action) {
            Group {
                switch interval {
                case .minutes(let m):
                    Text(String(format: String(localized: "%lld min", table: "HydrationReminder", bundle: .module), m))
                case .hours(let h):
                    Text(String(format: String(localized: "%lld hr", table: "HydrationReminder", bundle: .module), h))
                }
            }
            .font(.system(size: 10))
                .foregroundColor(isHovering ? .white : (isSelected ? .white : .secondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected || isHovering ? Color.blue : Color.secondary.opacity(0.1))
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
    }
}
