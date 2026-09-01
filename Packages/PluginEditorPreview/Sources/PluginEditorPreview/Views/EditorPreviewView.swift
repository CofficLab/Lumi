import AppKit
import KitMarkdown
import LumiUI
import SwiftUI

struct EditorPreviewView: View {
    @ObservedObject var viewModel: EditorPreviewViewModel
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minHeight: 100, idealHeight: 280, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .background(theme.surface)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye")
            Text(EditorPreviewLocalization.string("Preview"))
                .font(.appCaption)
            Spacer()
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .empty:
            placeholder(
                icon: "doc.richtext",
                title: EditorPreviewLocalization.string("No file selected"),
                message: EditorPreviewLocalization.string("Open a Markdown file to see its rendered preview.")
            )
        case .loading:
            placeholder(
                icon: "hourglass",
                title: EditorPreviewLocalization.string("Markdown Preview"),
                message: EditorPreviewLocalization.string("Preview is unavailable until the editor finishes loading the file.")
            )
        case .markdown(_, let markdown):
            ScrollView {
                MarkdownBlockRenderer(markdown: markdown, theme: .standard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
            }
        case .image(let url):
            if let image = NSImage(contentsOf: url) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(minWidth: 240, minHeight: 160)
                        .padding(24)
                }
            } else {
                placeholder(
                    icon: "photo",
                    title: EditorPreviewLocalization.string("Image Preview"),
                    message: EditorPreviewLocalization.string("Preview is not available for this file type.")
                )
            }
        case .unsupported(let url):
            placeholder(
                icon: "doc",
                title: url.lastPathComponent,
                message: EditorPreviewLocalization.string("Preview is not available for this file type.")
            )
        case .failed(let url, let message):
            placeholder(icon: "exclamationmark.triangle", title: url.lastPathComponent, message: message)
        }
    }

    private func placeholder(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(theme.textTertiary)
            Text(title)
                .font(.appBodyEmphasized)
                .foregroundStyle(theme.textPrimary)
            Text(message)
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
