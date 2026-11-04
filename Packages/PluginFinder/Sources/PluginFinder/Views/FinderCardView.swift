import LumiUI
import ProviderMessage
import SwiftUI

/// Finder 卡片视图。
///
/// 展示「图标 + 标题 + 描述 + 文件夹路径」，底部一个按钮在 Finder 中打开该文件夹。
///
/// 载荷缺失时（历史数据或载荷损坏）回退到纯文本摘要，避免渲染空白。
struct FinderCardView: View {
    @LumiTheme private var theme

    let payload: FinderCardPayload

    /// 点击按钮后的回调。由渲染器注入，负责真正调用 Finder。
    let onOpen: () -> Void

    /// 目标文件夹当前是否还存在。
    ///
    /// 卡片是持久化在消息里的：LLM 调用工具时文件夹还在，但用户过几天
    /// 再回看这条消息时它可能已被删除或移动。此时按钮会明确显示「文件夹不存在」
    /// 并置灰，而不是让用户点了之后毫无反应。
    private var isFolderAvailable: Bool {
        FinderOpener.validatedURL(for: payload.path) != nil
    }

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header

                Divider()
                    .overlay(theme.divider.opacity(0.6))

                pathRow

                if !isFolderAvailable {
                    unavailableNotice
                }

                action
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.primary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(payload.displayTitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = payload.displayDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
        }
    }

    // MARK: - Path

    private var pathRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 16)

            Text(pluginLocalization.string("Folder"))
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 48, alignment: .leading)

            Text(payload.path)
                .font(.caption)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Unavailable Notice

    private var unavailableNotice: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(theme.warning)

            Text(pluginLocalization.string("Folder does not exist"))
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Action

    private var action: some View {
        HStack {
            Spacer(minLength: 0)
            AppButton(
                payload.displayActionTitle ?? pluginLocalization.string("Open in Finder"),
                systemImage: "arrow.up.forward.app",
                style: .primary,
                size: .small,
                action: onOpen
            )
            .disabled(!isFolderAvailable)
        }
    }
}

/// 载荷缺失时的降级视图：只显示消息正文。
struct FinderCardFallbackView: View {
    @LumiTheme private var theme

    let message: Message

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            Text(message.content)
                .font(.callout)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
