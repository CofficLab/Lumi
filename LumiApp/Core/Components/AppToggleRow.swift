import SwiftUI

// MARK: - AppToggleRow

/// 统一的开关行组件：图标 + 标题 + 描述 + 开关
///
/// 用于设置页面的各项开关选项，替代手写的 `HStack { VStack { Text } Spacer() Toggle }` 模式。
///
/// ## 使用示例
/// ```swift
/// AppToggleRow(
///     title: "启用剪贴板监控",
///     systemImage: "clipboard",
///     isOn: $isMonitoringEnabled
/// )
///
/// AppToggleRow(
///     title: "自动切换输入法",
///     systemImage: "keyboard",
///     description: "根据应用自动切换输入法",
///     isOn: $autoSwitchEnabled
/// )
/// ```
struct AppToggleRow: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let description: LocalizedStringKey?
    @Binding var isOn: Bool

    /// 基础初始化
    init(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        description: LocalizedStringKey? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: AppUI.Spacing.md) {
            // 图标
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(AppUI.Color.semantic.primary)
                    .frame(width: 24)
            }

            // 标题和描述
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppUI.Typography.body)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                if let description {
                    Text(description)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
            }

            Spacer()

            // 开关
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, AppUI.Spacing.sm)
        .padding(.horizontal, AppUI.Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview("AppToggleRow") {
    VStack(spacing: 0) {
        AppToggleRow(
            title: "启用剪贴板监控",
            systemImage: "clipboard",
            isOn: .constant(true)
        )

        GlassDivider()

        AppToggleRow(
            title: "自动切换输入法",
            systemImage: "keyboard",
            description: "根据当前应用自动切换输入法",
            isOn: .constant(false)
        )

        GlassDivider()

        AppToggleRow(
            title: "仅显示活跃进程",
            isOn: .constant(true)
        )
    }
    .padding()
    .frame(width: 400)
    .background(AppUI.Color.basePalette.deepBackground)
}