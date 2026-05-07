import SwiftUI

// MARK: - AppLoadingOverlay

/// 统一的加载状态组件
///
/// 支持两种模式：
/// - 全屏覆盖模式（overlay）
/// - 内嵌模式（inline）
///
/// ## 使用示例
/// ```swift
/// // 全屏覆盖模式
/// AppLoadingOverlay(message: "正在加载...")
///     .frame(maxWidth: .infinity, maxHeight: .infinity)
///
/// // 小尺寸 spinner
/// AppLoadingOverlay(size: .small)
///
/// // 条件展示
/// if isLoading {
///     AppLoadingOverlay(message: "处理中...")
/// }
/// ```
struct AppLoadingOverlay: View {
    enum Size {
        case small
        case medium
        case large
    }

    let message: LocalizedStringKey?
    let size: Size

    /// 简单初始化（仅 spinner）
    init(size: Size = .medium) {
        self.message = nil
        self.size = size
    }

    /// 带消息的初始化
    init(message: LocalizedStringKey, size: Size = .medium) {
        self.message = message
        self.size = size
    }

    var body: some View {
        VStack(spacing: AppUI.Spacing.md) {
            ProgressView()
                .scaleEffect(scaleEffect)

            if let message {
                Text(message)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scaleEffect: CGFloat {
        switch size {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.5
        }
    }
}

// MARK: - Preview

#Preview("AppLoadingOverlay - Small") {
    AppLoadingOverlay(size: .small)
        .frame(width: 100, height: 100)
        .background(AppUI.Color.basePalette.deepBackground)
}

#Preview("AppLoadingOverlay - Medium") {
    AppLoadingOverlay(message: "正在加载...")
        .frame(width: 200, height: 150)
        .background(AppUI.Color.basePalette.deepBackground)
}

#Preview("AppLoadingOverlay - Large") {
    AppLoadingOverlay(message: "正在扫描应用...", size: .large)
        .frame(width: 300, height: 200)
        .background(AppUI.Color.basePalette.deepBackground)
}