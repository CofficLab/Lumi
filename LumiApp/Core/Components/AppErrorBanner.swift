import SwiftUI

// MARK: - AppErrorBanner

/// 统一的错误提示组件：图标 + 消息 + 可选重试按钮
///
/// 用于展示异步操作的错误信息，替代手写的 `errorMessage + Image + foregroundColor(.red)` 模式。
///
/// ## 使用示例
/// ```swift
/// // 仅消息
/// AppErrorBanner(message: "加载失败")
///
/// // 带重试按钮
/// AppErrorBanner(
///     message: "网络连接失败",
///     retryTitle: "重试",
///     onRetry: { /* 重新加载 */ }
/// )
/// ```
struct AppErrorBanner: View {
    let message: LocalizedStringKey
    let retryTitle: LocalizedStringKey?
    let onRetry: (() -> Void)?

    /// 基础初始化（仅消息）
    init(message: LocalizedStringKey) {
        self.message = message
        self.retryTitle = nil
        self.onRetry = nil
    }

    /// 带重试按钮的初始化
    init(message: LocalizedStringKey, retryTitle: LocalizedStringKey, onRetry: @escaping () -> Void) {
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    var body: some View {
        HStack(spacing: AppUI.Spacing.sm) {
            // 错误图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppUI.Color.semantic.error)

            // 错误消息
            Text(message)
                .font(AppUI.Typography.caption1)
                .foregroundColor(AppUI.Color.semantic.error)
                .lineLimit(nil)

            Spacer()

            // 重试按钮
            if let retryTitle, let onRetry {
                AppButton(retryTitle, style: .ghost, size: .small, action: onRetry)
            }
        }
        .padding(.horizontal, AppUI.Spacing.md)
        .padding(.vertical, AppUI.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                .fill(AppUI.Color.semantic.error.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                .stroke(AppUI.Color.semantic.error.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("AppErrorBanner - 仅消息") {
    AppErrorBanner(message: "加载失败，请稍后重试")
        .padding()
        .frame(width: 400)
        .background(AppUI.Color.basePalette.deepBackground)
}

#Preview("AppErrorBanner - 带重试") {
    AppErrorBanner(
        message: "网络连接失败",
        retryTitle: "重试",
        onRetry: { print("重试中...") }
    )
    .padding()
    .frame(width: 400)
    .background(AppUI.Color.basePalette.deepBackground)
}