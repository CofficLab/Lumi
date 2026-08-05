import SwiftUI
import UniformTypeIdentifiers

// MARK: - Booklet Drop Zone

/// Top section: a single drop zone that accepts a PDF, plus a small
/// summary of the loaded file.
struct BookletDropZoneView: View {

    @ObservedObject var viewModel: BookletMakerViewModel

    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.gray.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isTargeted
                                  ? Color.accentColor.opacity(0.08)
                                  : Color.gray.opacity(0.04))
                    )

                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(BookletLocalization.string(
                        "Drop a PDF here or click to choose one"))
                        .font(.headline)
                    if let info = viewModel.inputInfo {
                        Text(BookletLocalization.string(
                            "%@ · %lld pages · %lld×%lld pt",
                            viewModel.inputURL?.lastPathComponent ?? "",
                            info.pageCount,
                            Int(info.firstPageSize.width),
                            Int(info.firstPageSize.height)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .frame(height: 140)
            .contentShape(Rectangle())
            .onTapGesture { presentOpenPanel() }
            .onDrop(of: [.pdf, .fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            if viewModel.hasInput {
                HStack {
                    Label(
                        BookletLocalization.string("Output: %lld sheets")
                            .replacingOccurrences(of: "%lld", with: "\(viewModel.expectedSheetCount)"),
                        systemImage: "rectangle.split.2x1"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button(BookletLocalization.string("Clear")) {
                        viewModel.clear()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - Actions

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.loadPDF(url) }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, url.pathExtension.lowercased() == "pdf" else { return }
            Task { @MainActor in
                await viewModel.loadPDF(url)
            }
        }
        return true
    }
}
