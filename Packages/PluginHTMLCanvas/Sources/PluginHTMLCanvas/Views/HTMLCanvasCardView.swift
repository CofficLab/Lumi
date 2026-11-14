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

    /// 快照图片缓存。
    ///
    /// - Important: 快照原先是计算属性，每次 body 求值都同步读盘 + 解码 PNG。
    ///   body 每次求值都要重新做一次文件 IO 与解码（见 issue #1281）。
    ///   这里按路径缓存，只在路径变化时加载一次，且加载放在后台线程。
    @State private var snapshot: SnapshotImage?

    /// 快照缓存条目。
    private struct SnapshotImage {
        let path: String
        let image: LumiPlatformImage?
        /// HTML 文件是否存在（同样是一次文件系统查询，一并缓存）。
        let hasHTMLFile: Bool
    }

    /// 当前快照图片。为 nil 表示快照不可用，需要回退到活 WebView。
    private var snapshotImage: LumiPlatformImage? {
        guard let snapshot, snapshot.path == payload.snapshotPath else { return nil }
        return snapshot.image
    }

    /// 快照是否已加载完毕。
    ///
    /// - Note: 加载完成前不渲染 WebView 回退 —— 那会在快照可用时
    ///   先建一个 WKWebView 再被替换，白白多一次重活。
    private var snapshotResolved: Bool {
        snapshot?.path == payload.snapshotPath
    }

    /// HTML 文件是否存在。
    ///
    /// - Note: `payload.hasHTMLFile` 每次访问都做一次 `fileExists`，
    ///   body 每次求值都要重来一遍。缓存后只在加载任务里探测一次。
    private var hasHTMLFile: Bool {
        if let snapshot, snapshot.path == payload.snapshotPath {
            return snapshot.hasHTMLFile
        }
        return payload.hasHTMLFile
    }

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header

                Divider()
                    .overlay(theme.divider.opacity(0.6))

                preview

                if !hasHTMLFile {
                    unavailableNotice
                }
            }
        }
        .task(id: payload.snapshotPath) {
            await loadSnapshotIfNeeded()
        }
    }

    /// 按需加载快照图片。
    ///
    /// - Important: 文件 IO 与 PNG 解码放在后台线程，不占主线程
    ///   （见 issue #1281）。
    private func loadSnapshotIfNeeded() async {
        let path = payload.snapshotPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            snapshot = nil
            return
        }
        if let snapshot, snapshot.path == path {
            return
        }

        // 文件是否存在 + 读盘 + 解码都在后台线程完成：
        // `hasSnapshot` / `hasHTMLFile` 本身也是同步的文件系统查询。
        let loaded = await Task.detached(priority: .utility) { () -> (image: LumiPlatformImage?, hasHTMLFile: Bool) in
            let url = URL(fileURLWithPath: path)
            let image = FileManager.default.fileExists(atPath: path)
                ? LumiPlatformImage(lumiContentsOf: url)
                : nil
            let htmlPath = payload.htmlPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasHTML = !htmlPath.isEmpty && FileManager.default.fileExists(atPath: htmlPath)
            return (image, hasHTML)
        }.value

        guard !Task.isCancelled else { return }
        // 快照文件不存在时也要记下，避免每次 body 求值都重新探测。
        snapshot = SnapshotImage(
            path: path,
            image: loaded.image,
            hasHTMLFile: loaded.hasHTMLFile
        )
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
        } else if hasHTMLFile && !snapshotResolved {
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
