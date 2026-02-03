import SwiftUI
import MagicKit

/// 防休眠插件的状态栏弹窗视图
struct CaffeinateStatusBarPopupView: View {
    @State private var manager = CaffeinateManager.shared
    @State private var selectedDuration: TimeInterval = 0

    private let quickDurations: [(title: String, value: TimeInterval)] = [
        ("永久", 0),
        ("30分钟", 1800),
        ("1小时", 3600),
        ("2小时", 7200),
        ("5小时", 18000)
    ]

    var body: some View {
        VStack(spacing: 10) {
            // 标题栏
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(manager.isActive ? .orange : .secondary)

                Text("防休眠")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                // 状态指示器
                if manager.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 5, height: 5)

                        Text(elapsedTimeString)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 主控制区
            HStack(spacing: 8) {
                // 切换按钮
                Button(action: {
                    if manager.isActive {
                        manager.deactivate()
                    } else {
                        manager.activate(mode: .systemAndDisplay, duration: selectedDuration)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: manager.isActive ? "stop.fill" : "play.fill")
                            .font(.system(size: 11))

                        Text(manager.isActive ? "停止" : "启动")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(manager.isActive ? Color.orange : Color.green)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()

                // 模式切换
                Picker("", selection: Binding(
                    get: { manager.mode },
                    set: { newMode in
                        if manager.isActive {
                            let currentDuration = manager.duration
                            manager.deactivate()
                            manager.activate(mode: newMode, duration: currentDuration)
                        }
                    }
                )) {
                    Text("系统").tag(CaffeinateManager.SleepMode.systemOnly)
                    Text("系统+屏").tag(CaffeinateManager.SleepMode.systemAndDisplay)
                }
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .frame(width: 90)
                .disabled(!manager.isActive)
            }

            // 时长选择（仅未激活时显示）
            if !manager.isActive {
                HStack(spacing: 6) {
                    ForEach(quickDurations, id: \.value) { option in
                        Button(action: {
                            selectedDuration = option.value
                        }) {
                            Text(option.title)
                                .font(.system(size: 9))
                                .foregroundColor(selectedDuration == option.value ? .white : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedDuration == option.value ? Color.orange.opacity(0.8) : Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }

    private var elapsedTimeString: String {
        guard let startTime = manager.startTime else { return "" }
        let elapsed = Date().timeIntervalSince(startTime)

        if elapsed < 60 {
            return "\(Int(elapsed))秒"
        } else if elapsed < 3600 {
            let minutes = Int(elapsed / 60)
            return "\(minutes)分钟"
        } else {
            let hours = Int(elapsed / 3600)
            let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        }
    }
}

#Preview("Caffeinate Status Bar Popup") {
    CaffeinateStatusBarPopupView()
        .frame(width: 260)
        .padding()
}
