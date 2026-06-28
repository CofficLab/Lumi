import LumiUI
import SwiftUI

/// 防休眠插件的菜单栏弹窗视图
struct CaffeinateMenuBarPopupView: View {
    @State private var manager = CaffeinateManager.shared
    @State private var selectedDuration: TimeInterval = 0

    // 快捷操作类型
    enum QuickActionType: Equatable {
        case systemAndDisplay // 防止休眠且屏幕常亮
        case systemOnly // 防止休眠且允许屏幕关闭
        case turnOffDisplay // 防止休眠且立刻关闭屏幕
    }

    private let quickDurations: [(title: String, value: TimeInterval)] = [
        (PluginCaffeinateLocalization.string("Indefinite"), 0),
        (PluginCaffeinateLocalization.string("10 Min"), 600),
        (PluginCaffeinateLocalization.string("1 Hour"), 3600),
        (PluginCaffeinateLocalization.string("2 Hours"), 7200),
        (PluginCaffeinateLocalization.string("5 Hours"), 18000),
    ]

    /// 当前生效的快捷操作，由 manager 的真实状态推导，确保重新打开弹窗时对号仍然正确
    private var activeAction: QuickActionType? {
        guard manager.isActive else { return nil }
        switch manager.mode {
        case .systemAndDisplay:
            return .systemAndDisplay
        case .systemOnly:
            return .systemOnly
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 第一区块：时间选项
            durationSection

            GlassDivider()
                .padding(.horizontal, 12)

            // 第二区块：快捷菜单
            quickActionsSection
        }
        .padding(.vertical, 8)
    }

    // MARK: - 时间选择区块

    private var durationSection: some View {
        // 时间选项按钮
        HStack(spacing: 4) {
            ForEach(quickDurations, id: \.value) { option in
                DurationButton(
                    title: option.title,
                    isSelected: selectedDuration == option.value,
                    action: {
                        selectedDuration = option.value
                        // 如果防休眠正在运行，重新计时
                        if manager.isActive, let action = activeAction {
                            activateAction(action)
                        }
                    }
                )
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 快捷菜单区块

    private var quickActionsSection: some View {
        VStack(spacing: 0) {
            MenuBarActionRow(
                title: PluginCaffeinateLocalization.string("Prevent sleep & Keep screen on"),
                icon: "sun.max.fill",
                color: Color(hex: "FF9F0A"),
                isSelected: activeAction == .systemAndDisplay,
                action: {
                    toggleAction(.systemAndDisplay)
                }
            )

            GlassDivider()
                .padding(.leading, 36)

            MenuBarActionRow(
                title: PluginCaffeinateLocalization.string("Prevent sleep & Allow screen off"),
                icon: "moon.fill",
                color: Color(hex: "0A84FF"),
                isSelected: activeAction == .systemOnly,
                action: {
                    toggleAction(.systemOnly)
                }
            )

            GlassDivider()
                .padding(.leading, 36)

            MenuBarActionRow(
                title: PluginCaffeinateLocalization.string("Prevent sleep & Turn off screen"),
                icon: "power",
                color: Color(hex: "7C6FFF"),
                showCheckmark: false, // 瞬时操作，不显示对号
                action: {
                    // 立即关闭屏幕，并切换到"允许关闭"模式
                    // activateAndTurnOffDisplay 内部已将 mode 设为 .systemOnly，
                    // activeAction 由 manager 状态推导，对号会自动出现，无需手动赋值
                    manager.activateAndTurnOffDisplay(duration: selectedDuration)
                }
            )
        }
        .padding(.vertical, 4)
    }

    // MARK: - 辅助方法

    private func toggleAction(_ action: QuickActionType) {
        if activeAction == action {
            // 点击已选中的项，取消选中并停止
            // activeAction 由 manager 状态推导，deactivate 后会自动清空，无需手动重置
            manager.deactivate()
        } else {
            // 选中新项并启动
            activateAction(action)
        }
    }

    private func activateAction(_ action: QuickActionType) {
        switch action {
        case .systemAndDisplay:
            manager.activate(mode: .systemAndDisplay, duration: selectedDuration)
        case .systemOnly:
            manager.activate(mode: .systemOnly, duration: selectedDuration)
        case .turnOffDisplay:
            manager.activateAndTurnOffDisplay(duration: selectedDuration)
        }
    }
}

// MARK: - 时间选择按钮

private struct DurationButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(isSelected ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color(hex: "7C6FFF") : Color(hex: "98989E").opacity(0.2))
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }
}
