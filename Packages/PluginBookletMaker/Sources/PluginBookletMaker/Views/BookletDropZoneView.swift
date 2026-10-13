import LumiUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Booklet Drop Zone View

private final class PDFDropURLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []

    func append(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        urls.append(url)
    }

    func snapshot() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }
}

/// 拖放区域视图，用于接收用户拖入或选择的 PDF 文件
struct BookletDropZoneView: View {
    @LumiTheme private var theme

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
            if viewModel.selectedTool == .merge {
                mergeFileInfo
            } else {
                fileInfo
            }

            if let errorMessage = viewModel.errorMessage {
                AppErrorBanner(message: LocalizedStringKey(errorMessage))
            }
        }
        .padding()
        .appSurface(
            style: .subtle,
            cornerRadius: DesignTokens.Radius.md,
            borderColor: isTargeted ? theme.primary : theme.appSubtleBorder,
            lineWidth: isTargeted ? 2 : 1
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
                .foregroundStyle(theme.textSecondary)

            Text(viewModel.selectedTool == .merge
                 ? BookletLocalization.string("Drop PDFs here or click to choose files")
                 : BookletLocalization.string("Drop a PDF here or click to choose one"))
                .font(DesignTokens.Typography.bodyEmphasized)
                .foregroundStyle(theme.textSecondary)

            Text(BookletLocalization.string("Supports A4 PDF files"))
                .font(DesignTokens.Typography.caption1)
                .foregroundStyle(theme.textTertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectPDFFile()
        }
    }

    private var fileInfo: some View {
        HStack {
            Image(systemName: viewModel.currentDocument.isDemo ? "doc.text.fill" : "doc.fill")
                .foregroundStyle(theme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentDocument.isDemo
                     ? BookletLocalization.string("Built-in demo PDF")
                     : viewModel.currentDocument.url.lastPathComponent)
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(BookletLocalization.string(
                    "%lld pages",
                    Int64(viewModel.currentDocument.pageCount)
                ))
                    .font(DesignTokens.Typography.caption1)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            if viewModel.hasUserInput {
                AppButton(systemImage: "xmark.circle.fill", action: {
                    viewModel.clear()
                })
                .help(BookletLocalization.string("Return to built-in demo PDF"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .appSurface(style: .listRow, cornerRadius: DesignTokens.Radius.sm)
    }

    private var mergeFileInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(viewModel.mergeDocuments) { item in
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(theme.primary)
                    Text(item.url.lastPathComponent)
                        .font(DesignTokens.Typography.caption1)
                        .lineLimit(1)
                    Spacer()
                    Text(BookletLocalization.string("%lld pages", Int64(item.pageCount)))
                        .font(DesignTokens.Typography.caption1)
                        .foregroundStyle(theme.textSecondary)
                    AppButton(systemImage: "xmark.circle.fill") {
                        viewModel.removeMergeDocument(item)
                    }
                    .help(BookletLocalization.string("Remove"))
                }
            }
            Text(BookletLocalization.string(
                "%lld files · %lld pages",
                Int64(viewModel.mergeDocuments.count),
                Int64(viewModel.mergePageCount)
            ))
            .font(DesignTokens.Typography.caption1)
            .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .appSurface(style: .listRow, cornerRadius: DesignTokens.Radius.sm)
    }

    // MARK: - Actions

    private func selectPDFFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = viewModel.selectedTool == .merge
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                if viewModel.selectedTool == .merge {
                    await viewModel.loadMergePDFs(urls)
                } else if let url = urls.first {
                    await viewModel.loadPDF(url)
                }
            }
        }
        #else
        isPresentingImporter = true
        #endif
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let matchingProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !matchingProviders.isEmpty else {
            return false
        }

        let group = DispatchGroup()
        let collector = PDFDropURLCollector()
        for provider in matchingProviders {
            group.enter()
            provider.loadItem(
                forTypeIdentifier: UTType.fileURL.identifier,
                options: nil
            ) { item, _ in
                defer { group.leave() }
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
                collector.append(url)
            }
        }
        group.notify(queue: .main) {
            Task { @MainActor in
                let urls = collector.snapshot()
                if self.viewModel.selectedTool == .merge {
                    await self.viewModel.loadMergePDFs(urls)
                } else if let url = urls.first {
                    await self.viewModel.loadPDF(url)
                }
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
