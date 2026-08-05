import AppKit
import SwiftUI

// MARK: - Booklet Maker Main View

/// Top-level container that wires together the drop zone, the settings
/// panel, the progress row and the preview strip.
struct BookletMakerMainView: View {

    @StateObject private var viewModel = BookletMakerViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                BookletDropZoneView(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                BookletSettingsPanel(
                    viewModel: viewModel,
                    onExport: { presentSavePanel() }
                )
                .frame(width: 260)
            }

            BookletProgressView(viewModel: viewModel)

            BookletPreviewStrip(viewModel: viewModel)
        }
        .padding()
    }

    // MARK: - Actions

    private func presentSavePanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedFileName()
        panel.canCreateDirectories = true
        panel.title = BookletLocalization.string("Export Booklet PDF")
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.export(to: url) }
        }
    }

    private func suggestedFileName() -> String {
        let base = viewModel.inputURL?.deletingPathExtension().lastPathComponent
            ?? "booklet"
        return "\(base)-booklet.pdf"
    }
}

// MARK: - Preview

#Preview("Empty") {
    BookletMakerMainView()
        .frame(width: 900, height: 560)
}
