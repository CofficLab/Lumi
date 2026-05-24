import AppKit
import SwiftUI

/// 预览构建失败时显示的错误详情视图。
///
/// 展示失败类型标题、可复制的错误信息和一键复制按钮。
/// 使用实色背景遮挡底部的网格线，确保文字清晰可读。
struct PreviewFailureView: View {
    let failure: EditorPreviewViewModel.EntryFailure

    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: failure.systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                Text(failure.title)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

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
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
