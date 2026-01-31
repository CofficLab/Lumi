import SwiftUI
import Observation

/// 防休眠状态栏视图
struct CaffeinateStatusView: View {
    @State private var manager = CaffeinateManager.shared
    @State private var showDurationMenu = false

    var body: some View {
        Button(action: {
            manager.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: manager.isActive ? "bolt.fill" : "bolt")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(manager.isActive ? .yellow : .secondary)
                    .font(.system(size: 13))

                if manager.isActive, let duration = manager.getActiveDuration() {
                    Text(durationText(duration))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .popover(isPresented: $showDurationMenu, arrowEdge: .bottom) {
                durationMenuView
            }
        }
        .buttonStyle(.borderless)
        .help(manager.isActive ? "点击停止阻止休眠" : "点击阻止系统休眠")
        .onAppear {
            // 启动定时器更新显示
            startTimer()
        }
    }

    // MARK: - Duration Menu

    @ViewBuilder
    private var durationMenuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("选择持续时间")
                .font(.headline)
                .padding(.bottom, 8)

            Divider()

            ForEach(Array(CaffeinateManager.commonDurations.enumerated()), id: \.offset) { _, option in
                Button(action: {
                    activateWithDuration(option)
                    showDurationMenu = false
                }) {
                    HStack {
                        Text(option.icon)
                            .frame(width: 20)
                        Text(option.displayName)
                        Spacer()
                        if manager.isActive && manager.duration == option.timeInterval {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 6)
            }

            Divider()
                .padding(.vertical, 4)

            if manager.isActive {
                Button(action: {
                    manager.deactivate()
                    showDurationMenu = false
                }) {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(.red)
                        Text("停止阻止休眠")
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 6)
            }
        }
        .padding()
        .frame(width: 200)
    }

    // MARK: - Helpers

    private func activateWithDuration(_ option: CaffeinateManager.DurationOption) {
        if manager.isActive {
            manager.deactivate()
        }
        manager.activate(duration: option.timeInterval)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func startTimer() {
        // 使用 Timer 每秒更新一次显示
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if manager.isActive {
                // 触发视图更新
                // SwiftUI 会自动重新计算 body
            }
        }
    }
}

// MARK: - Preview

#Preview("Caffeinate Status - Inactive") {
    HStack(spacing: 16) {
        CaffeinateStatusView()
            .frame(width: 150)

        Divider()

        CaffeinateStatusView()
            .frame(width: 150)
            .preferredColorScheme(.dark)
    }
    .padding()
}

#Preview("Caffeinate Status - Active") {
    HStack(spacing: 16) {
        CaffeinateStatusView()
            .frame(width: 150)

        Divider()

        CaffeinateStatusView()
            .frame(width: 150)
            .preferredColorScheme(.dark)
    }
    .padding()
    .onAppear {
        CaffeinateManager.shared.activate()
    }
}
