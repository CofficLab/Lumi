import Foundation
import KitHTMLPreview
import LumiUI
import ProviderMessage
import SwiftUI

/// HTML 界面卡片视图。
///
/// 展示「标题 + 界面预览」。预览默认是工具预先渲染好的 PNG 快照——
/// 纯图片，不抢外层消息列表的滚动，也不会因 `List` 惰性物化反复重建
/// WKWebView。快照缺失时回退到直接加载 HTML 文件。
///
/// 载荷缺失时（历史数据或载荷损坏）回退到纯文本摘要，避免渲染空白。
struct HTMLCanvasCardView: View {
    @LumiTheme private var theme

    let payload: HTMLCanvasPayload

    /// 快照图片。为 nil 表示快照不可用，需要回退到活 WebView。
    private var snapshotImage: LumiPlatformImage? {
        guard payload.hasSnapshot else { return nil }
        return LumiPlatformImage(lumiContentsOf: URL(fileURLWithPath: payload.snapshotPath))
    }

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header

                Divider()
                    .overlay(theme.divider.opacity(0.6))

                preview

                if !payload.hasHTMLFile {
                    unavailableNotice
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.primary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(payload.displayTitle ?? pluginLocalization.string("HTML Preview"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(Int(payload.width)) × \(Int(payload.height))")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer(minLength: 8)
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        if let snapshotImage {
            Image(lumiImage: snapshotImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: previewHeight)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.divider.opacity(0.6), lineWidth: 1)
                )
        } else if payload.hasHTMLFile {
            // 快照渲染失败时的回退：直接加载 HTML 文件。
            // 用 contentSize 固定视口，外层容器裁剪，避免 WebView 撑开消息行。
            HTMLPreviewView(
                htmlText: "",
                fileURL: URL(fileURLWithPath: payload.htmlPath),
                contentSize: payload.canvasSize
            )
            .frame(height: previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.divider.opacity(0.6), lineWidth: 1)
            )
        } else {
            missingContent
        }
    }

    /// 预览区高度。
    ///
    /// 按画布宽高比换算，但限制在合理区间内：太矮看不清，
    /// 太高会把聊天记录推得很远。
    private var previewHeight: CGFloat {
        guard payload.width > 0 else { return 240 }
        let scaled = payload.height * (640 / payload.width)
        return min(max(scaled, 180), 520)
    }

    private var missingContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18))
                .foregroundStyle(theme.warning)
            Text(pluginLocalization.string("HTML content is no longer available"))
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(theme.elevatedSurface.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Unavailable Notice

    private var unavailableNotice: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(theme.warning)

            Text(pluginLocalization.string("HTML content is no longer available"))
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 载荷缺失时的降级视图：只显示消息正文。
struct HTMLCanvasFallbackView: View {
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
