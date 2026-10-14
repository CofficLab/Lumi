#if os(iOS)
import PDFKit
import SwiftUI

/// 导出结果页：成功展示生成的文件（缩略图 / 名称 / 大小）并提供
/// 分享、保存到文件与完成操作；失败展示可理解的原因。
struct BookletExportResultMobileView: View {
    @ObservedObject var feature: BookletMakerMobileFeature
    let outcome: BookletMakerMobileFeature.ExportOutcome

    var body: some View {
        NavigationStack {
            Group {
                switch outcome {
                case .success(let urls):
                    successContent(urls)
                case .failure(let message):
                    failureContent(message)
                }
            }
            .navigationTitle(BookletLocalization.string("Export"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(BookletLocalization.string("Done")) {
                        feature.dismissExportResult()
                    }
                }
            }
        }
    }

    // MARK: - Success

    private func successContent(_ urls: [URL]) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    ForEach(Array(urls.enumerated()), id: \.element.path) { index, url in
                        fileRow(url, index: index)
                        if index < urls.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 12) {
                    Button {
                        feature.presentShare()
                    } label: {
                        Label(BookletLocalization.string("Share"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        feature.presentSave()
                    } label: {
                        Label(BookletLocalization.string("Save to Files"), systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding(16)
        }
    }

    private func fileRow(_ url: URL, index: Int) -> some View {
        HStack(spacing: 12) {
            PDFDocumentPageView(documentURL: url, pageNumber: 1)
                .frame(width: 34, height: 46)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.body)
                    .lineLimit(1)
                Text(BookletLocalization.string(
                    "%@ · %lld pages",
                    formattedFileSize(url),
                    Int64(bookletPageCount(for: url) ?? 1)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(10)
    }

    private func bookletPageCount(for url: URL) -> Int? {
        guard let doc = PDFDocument(url: url) else { return nil }
        return doc.pageCount
    }

    private func formattedFileSize(_ url: URL) -> String {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return "–"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    // MARK: - Failure

    private func failureContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(BookletLocalization.string("Done")) {
                feature.dismissExportResult()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
