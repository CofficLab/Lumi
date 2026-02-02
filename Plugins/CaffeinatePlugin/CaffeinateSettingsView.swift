import Observation
import SwiftUI
import Combine

/// 防休眠设置视图
struct CaffeinateSettingsView: View {
    @State private var manager = CaffeinateManager.shared
    @State private var customHours: Int = 1
    @State private var customMinutes: Int = 0
    @State private var now = Date()
    
    // 定时器用于更新 UI
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. 状态卡片 (Hero Section)
                statusCard
                
                // 2. 快速设置 (Grid)
                quickSettingsSection
                
                // 3. 自定义时长 (Card)
                customSettingsSection
                
                // 4. 说明信息
                infoSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor)) // 更好的背景色支持
        .navigationTitle("防休眠控制")
        .onReceive(timer) { input in
            if manager.isActive {
                now = input
            }
        }
        .onAppear {
            // 初始化自定义时间为默认值或上次记忆的值(如果有)
        }
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Label(manager.isActive ? "正在运行" : "已暂停",
                          systemImage: manager.isActive ? "bolt.fill" : "moon.zzz.fill")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(manager.isActive ? .white : .primary)
                    
                    if manager.isActive {
                        Text("已持续运行: \(formatActiveDuration())")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(manager.isActive ? .white.opacity(0.9) : .secondary)
                        
                        if manager.duration > 0 {
                            Text("剩余时间: \(formatRemainingDuration())")
                                .font(.caption)
                                .foregroundStyle(manager.isActive ? .white.opacity(0.7) : .secondary)
                        }
                    } else {
                        Text("系统将遵循默认电源策略")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // 大开关按钮
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        manager.toggle()
                    }
                }) {
                    Image(systemName: manager.isActive ? "power" : "power")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(manager.isActive ? .white : .green)
                        .frame(width: 70, height: 70)
                        .background(
                            Circle()
                                .fill(manager.isActive ? .white.opacity(0.2) : Color.accentColor.opacity(0.1))
                        )
                        .overlay(
                            Circle()
                                .stroke(manager.isActive ? .white : Color.accentColor, lineWidth: 2)
                                .opacity(0.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(manager.isActive ? "停止防休眠" : "启动防休眠")
            }
        }
        .padding(24)
        .background(
            ZStack {
                if manager.isActive {
                    LinearGradient(
                        colors: [Color.green.opacity(0.8), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color(nsColor: .controlBackgroundColor)
                }
            }
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Quick Settings
    
    private var quickSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("快速启动", systemImage: "bolt.badge.clock.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CaffeinateManager.commonDurations, id: \.hashValue) { option in
                    Button(action: {
                        activateWithOption(option)
                    }) {
                        HStack {
                            Image(systemName: iconForOption(option))
                                .font(.title3)
                            
                            Text(option.displayName)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if manager.isActive && manager.duration == option.timeInterval {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(manager.isActive && manager.duration == option.timeInterval ? Color.green : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Custom Settings
    
    private var customSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("自定义时长", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    timeStepper(value: $customHours, range: 0...24, unit: "小时")
                    Divider().frame(height: 40)
                    timeStepper(value: $customMinutes, range: 0...59, step: 5, unit: "分钟")
                }
                
                Button(action: activateWithCustomDuration) {
                    Text("启动自定义倒计时")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(customHours == 0 && customMinutes == 0)
                .opacity((customHours == 0 && customMinutes == 0) ? 0.6 : 1.0)
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    private func timeStepper(value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Button(action: { if value.wrappedValue > range.lowerBound { value.wrappedValue -= step } }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary.opacity(0.5))
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                Text("\(value.wrappedValue)")
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(minWidth: 40)
                    .multilineTextAlignment(.center)
                
                Button(action: { if value.wrappedValue < range.upperBound { value.wrappedValue += step } }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.secondary.opacity(0.5))
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("关于防休眠", systemImage: "info.circle")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Text("防休眠功能可以阻止系统在空闲时自动进入睡眠状态，适用于长时间下载、编译代码或演示等场景。当倒计时结束或手动停止后，系统将恢复正常的电源管理策略。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Helpers
    
    private func activateWithOption(_ option: CaffeinateManager.DurationOption) {
        withAnimation {
            if manager.isActive {
                manager.deactivate()
            }
            manager.activate(duration: option.timeInterval)
        }
    }
    
    private func activateWithCustomDuration() {
        let totalSeconds = customHours * 3600 + customMinutes * 60
        withAnimation {
            if manager.isActive {
                manager.deactivate()
            }
            manager.activate(duration: TimeInterval(totalSeconds))
        }
    }
    
    private func iconForOption(_ option: CaffeinateManager.DurationOption) -> String {
        switch option {
        case .indefinite: return "infinity"
        case .minutes: return "timer"
        case .hours: return "hourglass"
        }
    }
    
    private func formatActiveDuration() -> String {
        guard let activeDuration = manager.getActiveDuration() else { return "00:00" }
        return formatTimeInterval(activeDuration)
    }
    
    private func formatRemainingDuration() -> String {
        guard let startTime = manager.startTime else { return "" }
        // 使用 now 确保视图刷新依赖
        _ = now 
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = max(0, manager.duration - elapsed)
        return formatTimeInterval(remaining)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Previews

#Preview {
    CaffeinateSettingsView()
        .frame(width: 400, height: 600)
}

