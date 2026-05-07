import SwiftUI

// MARK: - AppEmptyState

/// 统一的空状态组件：图标 + 标题 + 描述 + 可选操作按钮
///
/// 用于列表为空、无搜索结果、无数据等场景，替代 14+ 个重复的 EmptyXxxView 文件。
///
/// ## 使用示例
/// ```swift
/// // 基础用法
/// AppEmptyState(
///     icon: "tray",
///     title: "暂无数据"
/// )
///
/// // 带描述
/// AppEmptyState(
///     icon: "magnifyingglass",
///     title: "未找到相关内容",
///     description: "请尝试其他搜索关键词"
/// )
///
/// // 带操作按钮
/// AppEmptyState(
///     icon: "arrow.down.circle",
///     title: "暂无已下载的模型",
///     actionTitle: "浏览模型",
///     action: { /* 跳转到模型列表 */ }
/// )
/// ```
struct AppEmptyState: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey?
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    /// 基础初始化
    init(
        icon: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = nil
        self.action = nil
    }

    /// 带操作按钮的初始化
    init(
        icon: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppUI.Spacing.md) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppUI.Color.semantic.textSecondary.opacity(0.6))

            // 标题
            Text(title)
                .font(AppUI.Typography.bodyEmphasized)
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            // 描述
            if let description {
                Text(description)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .multilineTextAlignment(.center)
            }

            // 操作按钮
            if let actionTitle, let action {
                AppButton(actionTitle, style: .secondary, size: .small, action: action)
                    .padding(.top, AppUI.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppUI.Spacing.xl)
    }
}

// MARK: - Preview

#Preview("AppEmptyState - 基础") {
    AppEmptyState(
        icon: "tray",
        title: "暂无数据"
    )
    .frame(width: 400, height: 300)
    .background(AppUI.Color.basePalette.deepBackground)
}

#Preview("AppEmptyState - 带描述") {
    AppEmptyState(
        icon: "magnifyingglass",
        title: "未找到相关内容",
        description: "请尝试其他搜索关键词"
    )
    .frame(width: 400, height: 300)
    .background(AppUI.Color.basePalette.deepBackground)
}

#Preview("AppEmptyState - 带操作按钮") {
    AppEmptyState(
        icon: "arrow.down.circle",
        title: "暂无已下载的模型",
        description: "从模型列表中选择并下载",
        actionTitle: "浏览模型",
        action: { print("浏览模型") }
    )
    .frame(width: 400, height: 300)
    .background(AppUI.Color.basePalette.deepBackground)
}