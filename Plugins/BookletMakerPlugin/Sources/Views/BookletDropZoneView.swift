import SwiftUI

// MARK: - Booklet Drop Zone View

/// 拖放区域视图，用于接收用户拖入或选择的 PDF 文件
struct BookletDropZoneView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            // 拖放区域
            dropZone
                .frame(height: 120)

            // 文件信息
            if let inputURL = viewModel.inputURL {
                fileInfo(for: inputURL)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isTargeted ? 2 : 1)
        )
        .onDrop(of: [.pdf], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Sub Views

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text(BookletLocalization.string("Drop PDF here or click to select"))
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

    private func fileInfo(for url: URL) -> some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let info = viewModel.inputInfo {
                    Text(BookletLocalization.string("%lld pages", Int64(info.pageCount)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                viewModel.clear()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    // MARK: - Actions

    private func selectPDFFile() {
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

        _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, url.pathExtension.lowercased() == "pdf" else { return }
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
