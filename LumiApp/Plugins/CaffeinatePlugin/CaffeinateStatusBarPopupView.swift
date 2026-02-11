import MagicKit
import SwiftUI

/// 防休眠插件的状态栏弹窗视图
struct CaffeinateStatusBarPopupView: View {
    @State private var manager = CaffeinateManager.shared
    @State private var selectedDuration: TimeInterval = 0

    // 快捷操作类型
    enum QuickActionType: Equatable {
        case systemAndDisplay // 防止休眠且屏幕常亮
        case systemOnly // 防止休眠且允许屏幕关闭
        case turnOffDisplay // 防止休眠且立刻关闭屏幕
    }

    @State private var activeAction: QuickActionType? = nil

    private let quickDurations: [(title: String, value: TimeInterval)] = [
        (String(localized: "Indefinite"), 0),
        (String(localized: "10 Min"), 600),
        (String(localized: "1 Hour"), 3600),
        (String(localized: "2 Hours"), 7200),
        (String(localized: "5 Hours"), 18000),
    ]

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
        .onChange(of: manager.isActive) { _, newValue in
            // 当防休眠状态改变时，同步更新选中状态
            if !newValue {
                activeAction = nil
            }
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
        .padding(.vertical, 4)
    }

    // MARK: - 快捷菜单区块

    private var quickActionsSection: some View {
        VStack(spacing: 0) {
            QuickActionMenuItem(
                title: String(localized: "Prevent sleep & Keep screen on"),
                icon: "sun.max.fill",
                color: DesignTokens.Color.semantic.warning,
                isSelected: activeAction == .systemAndDisplay,
                action: {
                    toggleAction(.systemAndDisplay)
                }
            )

            GlassDivider()
                .padding(.leading, 36)

            QuickActionMenuItem(
                title: String(localized: "Prevent sleep & Allow screen off"),
                icon: "moon.fill",
                color: DesignTokens.Color.semantic.info,
                isSelected: activeAction == .systemOnly,
                action: {
                    toggleAction(.systemOnly)
                }
            )

            GlassDivider()
                .padding(.leading, 36)

            QuickActionMenuItem(
                title: String(localized: "Prevent sleep & Turn off screen"),
                icon: "power",
                color: DesignTokens.Color.semantic.primary,
                showCheckmark: false, // 瞬时操作，不显示对号
                action: {
                    // 立即关闭屏幕，并切换到"允许关闭"模式
                    manager.activateAndTurnOffDisplay(duration: selectedDuration)
                    activeAction = .systemOnly
                }
            )
        }
        .padding(.vertical, 4)
    }

    // MARK: - 辅助方法

    private func toggleAction(_ action: QuickActionType) {
        if activeAction == action {
            // 点击已选中的项，取消选中并停止
            activeAction = nil
            manager.deactivate()
        } else {
            // 选中新项并启动
            activeAction = action
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
                .foregroundColor(isSelected ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Caffeinate Status Bar Popup") {
    CaffeinateStatusBarPopupView()
        .frame(width: 280)
        .padding()
}

// MARK: - 快捷菜单项

private struct QuickActionMenuItem: View {
    let title: String
    let icon: String
    let color: Color
    var isSelected: Bool = false
    var showCheckmark: Bool? = nil // nil 表示根据 isSelected 自动决定
    let action: () -> Void

    @State private var isHovering = false

    private var shouldShowCheckmark: Bool {
        if let showCheckmark = showCheckmark {
            return showCheckmark
        }
        return isSelected
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isHovering ? DesignTokens.Color.semantic.textPrimary : color)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(isHovering ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)

                Spacer()

                // 显示对号
                if shouldShowCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isHovering ? DesignTokens.Color.semantic.textPrimary : color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(isHovering ? DesignTokens.Color.semantic.primary.opacity(0.2) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
