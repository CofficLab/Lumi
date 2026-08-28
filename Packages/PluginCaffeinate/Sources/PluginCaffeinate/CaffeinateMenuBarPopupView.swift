import LumiUI
import SwiftUI
import KitLocalization

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
        (LumiPluginLocalization.string("Indefinite", bundle: .module), 0),
        (LumiPluginLocalization.string("10 Min", bundle: .module), 600),
        (LumiPluginLocalization.string("1 Hour", bundle: .module), 3600),
        (LumiPluginLocalization.string("2 Hours", bundle: .module), 7200),
        (LumiPluginLocalization.string("5 Hours", bundle: .module), 18000),
    ]

    /// 当前生效的快捷操作，由 manager 的真实状态推导，确保重新打开弹窗时对号仍然正确
    private var activeAction: QuickActionType? {
        guard manager.isActive else { return nil }
        if manager.isDisplayOffRequested {
            return .turnOffDisplay
        }
        switch manager.mode {
        case .systemAndDisplay:
            return .systemAndDisplay
        case .systemOnly:
            return .systemOnly
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 第一区块:时间选项(self-contained,自带 padding)
            durationSection

            Divider()

            // 第二区块:快捷菜单(self-contained,自带 padding)
            quickActionsSection
        }
        .onAppear {
            // 配置由主插件在 onBoot 时完成；此处仅刷新视图状态。
        }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 快捷菜单区块

    private var quickActionsSection: some View {
        // MenuBarActionRow 自身带水平 padding(.horizontal, 12),
        // 因此区块无需再额外施加水平 padding,与 NetworkMenuBarPopupView
        // 中的 miniTrendView 风格一致。
        VStack(spacing: 0) {
            MenuBarActionRow(
                title: LumiPluginLocalization.string("Prevent sleep & Keep screen on", bundle: .module),
                icon: "sun.max.fill",
                color: Color(hex: "FF9F0A"),
                isSelected: activeAction == .systemAndDisplay,
                action: {
                    toggleAction(.systemAndDisplay)
                }
            )

            Divider()
                .padding(.leading, 36)

            MenuBarActionRow(
                title: LumiPluginLocalization.string("Prevent sleep & Allow screen off", bundle: .module),
                icon: "moon.fill",
                color: .blue,
                isSelected: activeAction == .systemOnly,
                action: {
                    toggleAction(.systemOnly)
                }
            )

            Divider()
                .padding(.leading, 36)

            MenuBarActionRow(
                title: LumiPluginLocalization.string("Prevent sleep & Turn off screen", bundle: .module),
                icon: "power",
                color: Color(hex: "7C6FFF"),
                isSelected: activeAction == .turnOffDisplay,
                action: {
                    if activeAction == .turnOffDisplay {
                        manager.deactivate()
                    } else {
                        manager.activateAndTurnOffDisplay(duration: selectedDuration)
                    }
                }
            )
        }
        .padding(.vertical, 8)
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
        if manager.isActive {
            manager.deactivate()
        }

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
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.16))
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }
}
