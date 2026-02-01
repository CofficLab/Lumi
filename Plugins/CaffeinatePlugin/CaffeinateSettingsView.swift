import Observation
import SwiftUI

/// 防休眠设置视图
struct CaffeinateSettingsView: View {
    @State private var manager = CaffeinateManager.shared
    @State private var selectedTab: DisplayTab = .quick
    @State private var customHours: Int = 1
    @State private var customMinutes: Int = 0
    @State private var isRunning: Bool = false

    enum DisplayTab: String, CaseIterable {
        case quick = "快速设置"
        case custom = "自定义"
        case status = "状态"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            // 标签页选择器
            tabPicker

            // 内容区域
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .quick:
                        quickSettingsView
                    case .custom:
                        customSettingsView
                    case .status:
                        statusView
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
        .onAppear {
            updateTimer()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 16) {
            Image(systemName: manager.isActive ? "bolt.fill" : "bolt")
                .font(.system(size: 32))
                .foregroundStyle(manager.isActive ? .yellow : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("防休眠设置")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(manager.isActive ? "已激活" : "未激活")
                    .font(.caption)
                    .foregroundStyle(manager.isActive ? .green : .secondary)
            }

            Spacer()

            // 大开关按钮
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    if manager.isActive {
                        manager.deactivate()
                    } else {
                        manager.activate()
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: manager.isActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title3)
                    Text(manager.isActive ? "停止" : "启动")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(manager.isActive ? .red : .green)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill((manager.isActive ? Color.red : Color.green).opacity(0.15))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(DisplayTab.allCases, id: \.rawValue) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedTab == tab ?
                                Color.accentColor.opacity(0.1) : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Quick Settings View

    private var quickSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择预设时长")
                .font(.headline)
                .padding(.bottom, 8)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CaffeinateManager.commonDurations, id: \.hashValue) { option in
                    DurationButton(
                        option: option,
                        isSelected: manager.isActive && manager.duration == option.timeInterval,
                        action: {
                            activateWithOption(option)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Custom Settings View

    private var customSettingsView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 自定义时长输入
            VStack(alignment: .leading, spacing: 12) {
                Text("设置自定义时长")
                    .font(.headline)

                HStack(spacing: 16) {
                    // 小时输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("小时")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Stepper(value: $customHours, in: 0...24) {
                            Text("\(customHours) 小时")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(minWidth: 80)
                        }
                    }

                    // 分钟输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分钟")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Stepper(value: $customMinutes, in: 0...59, step: 5) {
                            Text("\(customMinutes) 分钟")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(minWidth: 80)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }

            // 总时长显示
            let totalSeconds = customHours * 3600 + customMinutes * 60
            VStack(alignment: .leading, spacing: 8) {
                Text("总计时长")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatDuration(TimeInterval(totalSeconds)))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(12)

            // 启动按钮
            Button(action: {
                activateWithCustomDuration()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("启动防休眠")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(totalSeconds == 0)
            .opacity(totalSeconds == 0 ? 0.5 : 1)
        }
    }

    // MARK: - Status View

    private var statusView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if manager.isActive {
                // 激活状态卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("防休眠已激活")
                            .font(.headline)
                    }

                    Divider()

                    if let startTime = manager.startTime {
                        VStack(alignment: .leading, spacing: 8) {
                            StatusRow(label: "开始时间", value: formatDate(startTime))
                            StatusRow(label: "已运行时间", value: formatActiveDuration())
                            StatusRow(label: "设定时长", value: formatDuration(manager.duration))
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                // 未激活状态
                VStack(spacing: 16) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("防休眠未激活")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("系统将按照正常设置休眠")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }

            // 统计信息
            VStack(alignment: .leading, spacing: 12) {
                Text("会话信息")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("防止系统进入空闲休眠状态，保持屏幕和系统运行。适用于长时间下载、渲染、编译等场景。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helper Views

    struct DurationButton: View {
        let option: CaffeinateManager.DurationOption
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 12) {
                    Text(option.icon)
                        .font(.title)

                    Text(option.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ?
                            Color.accentColor.opacity(0.15) :
                                Color(.controlBackgroundColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    struct StatusRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Helper Methods

    private func activateWithOption(_ option: CaffeinateManager.DurationOption) {
        if manager.isActive {
            manager.deactivate()
        }
        manager.activate(duration: option.timeInterval)
    }

    private func activateWithCustomDuration() {
        let totalSeconds = customHours * 3600 + customMinutes * 60
        if manager.isActive {
            manager.deactivate()
        }
        manager.activate(duration: TimeInterval(totalSeconds))
        selectedTab = .status
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration == 0 {
            return "永久"
        }

        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60

        if hours > 0 && minutes > 0 {
            return "\(hours) 小时 \(minutes) 分钟"
        } else if hours > 0 {
            return "\(hours) 小时"
        } else {
            return "\(minutes) 分钟"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatActiveDuration() -> String {
        guard let activeDuration = manager.getActiveDuration() else {
            return "0 秒"
        }

        let hours = Int(activeDuration) / 3600
        let minutes = Int(activeDuration) / 60 % 60
        let seconds = Int(activeDuration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func updateTimer() {
        // 每秒更新一次界面
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if manager.isActive {
                // 触发视图更新
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CaffeinateSettingsView()
        .frame(width: 600, height: 500)
}
