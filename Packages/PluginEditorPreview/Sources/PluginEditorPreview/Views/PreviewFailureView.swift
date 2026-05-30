import AppKit
import SwiftUI

/// 预览构建失败时显示的错误详情视图。
///
/// 展示失败类型标题、可复制的错误信息、一键复制按钮以及日志文件入口。
/// 使用实色背景遮挡底部的网格线，确保文字清晰可读。
public struct PreviewFailureView: View {
    public let failure: EditorPreviewViewModel.EntryFailure
    public let buildLogURL: URL?
    public var onRetry: (() -> Void)?

    @State private var isCopied = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: failure.systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                Text(failure.title)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button {
                    onRetry?()
                } label: {
                    Label(String(localized: "Retry", table: "EditorPreview"), systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Retry preview build", table: "EditorPreview"))

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(failure.message, forType: .string)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCopied = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isCopied = false
                            }
                        }
                    }
                } label: {
                    Label(isCopied ? String(localized: "Copied", table: "EditorPreview") : String(localized: "Copy", table: "EditorPreview"),
                          systemImage: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(isCopied ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Copy error message to clipboard", table: "EditorPreview"))
            }

            ScrollView {
                Text(failure.message)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let buildLogURL {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Build log saved:", table: "EditorPreview"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([buildLogURL])
                    } label: {
                        Text(buildLogURL.lastPathComponent)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.blue)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Show log file in Finder", table: "EditorPreview"))
                    .draggable(buildLogURL.path)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
