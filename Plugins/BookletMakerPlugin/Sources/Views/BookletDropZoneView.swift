import LumiUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Booklet Drop Zone View

/// 拖放区域视图，用于接收用户拖入或选择的 PDF 文件
struct BookletDropZoneView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    @State private var isTargeted: Bool = false
    #if os(iOS)
    @State private var isPresentingImporter = false
    #endif

    var body: some View {
        VStack(spacing: 12) {
            // 拖放区域
            dropZone
                .frame(height: 120)

            // 文件信息
            fileInfo

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lumiControlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isTargeted ? 2 : 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        #if os(iOS)
        .fileImporter(isPresented: $isPresentingImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result {
                Task { await viewModel.loadPDF(url) }
            }
        }
        #endif
    }

    // MARK: - Sub Views

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text(BookletLocalization.string("Drop a PDF here or click to choose one"))
                .font(.headline)
                .foregroundColor(.secondary)

            Text(BookletLocalization.string("Supports A4 PDF files"))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectPDFFile()
        }
    }

    private var fileInfo: some View {
        HStack {
            Image(systemName: viewModel.currentDocument.isDemo ? "doc.text.fill" : "doc.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentDocument.isDemo
                     ? BookletLocalization.string("Built-in demo PDF")
                     : viewModel.currentDocument.url.lastPathComponent)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(BookletLocalization.string(
                    "%lld pages",
                    Int64(viewModel.currentDocument.pageCount)
                ))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if viewModel.hasUserInput {
                Button(action: {
                    viewModel.clear()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(BookletLocalization.string("Return to built-in demo PDF"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.lumiTextBackground)
        )
    }

    // MARK: - Actions

    private func selectPDFFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.loadPDF(url) }
        }
        #else
        isPresentingImporter = true
        #endif
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        provider.loadItem(
            forTypeIdentifier: UTType.fileURL.identifier,
            options: nil
        ) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let itemURL = item as? URL {
                url = itemURL
            } else if let itemURL = item as? NSURL {
                url = itemURL as URL
            } else {
                url = nil
            }

            guard let url, url.pathExtension.lowercased() == "pdf" else { return }
            Task { @MainActor in
                await viewModel.loadPDF(url)
            }
        }
        return true
    }
}

// MARK: - Preview

#Preview("Empty State") {
    BookletDropZoneView(viewModel: BookletMakerViewModel())
        .frame(width: 500, height: 400)
        .padding()
}
