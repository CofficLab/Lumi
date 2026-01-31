import Observation
import SwiftUI

/// 防休眠设置视图
struct CaffeinateSettingsView: View {
    @State private var manager = CaffeinateManager.shared

    var body: some View {
        VStack(spacing: 24) {
            // 标题
            VStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)

                Text("防休眠设置")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding(.top, 40)

            // 当前状态
            VStack(spacing: 12) {
                HStack {
                    Text("当前状态:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(manager.isActive ? "已激活" : "未激活")
                        .foregroundStyle(manager.isActive ? .green : .secondary)
                }

                if manager.isActive, let duration = manager.getActiveDuration() {
                    HStack {
                        Text("运行时间:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(durationText(duration))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            // 常用时间选项
            VStack(alignment: .leading, spacing: 12) {
                Text("快速设置")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(CaffeinateManager.commonDurations, id: \.hashValue) { option in
                    Button(action: {
                        activateWithDuration(option)
                    }) {
                        HStack {
                            Text(option.icon)
                                .frame(width: 30)
                            Text(option.displayName)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(manager.isActive && manager.duration == option.timeInterval ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

// MARK: - Preview

#Preview {
    CaffeinateSettingsView()
}
