#if os(iOS)
import PDFKit
import SwiftUI

/// Finished export state with file details, sharing, saving, and next actions.
struct BookletExportResultMobileView: View {
    @ObservedObject var feature: BookletMakerMobileFeature
    let outcome: BookletMakerMobileFeature.ExportOutcome

    private var isSplit: Bool { feature.selectedTool == .split }

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
            .background(BookletMobileStyle.canvas)
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
        .tint(BookletMobileStyle.accent)
    }

    private func successContent(_ urls: [URL]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BookletMobileProgressView(current: isSplit ? 3 : 6, total: isSplit ? 3 : 6)

                HStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(BookletMobileStyle.actionFill, in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(BookletLocalization.string("Your PDF is ready"))
                            .font(.headline)
                        Text(urls.count == 1
                             ? BookletLocalization.string("One file created on this device")
                             : BookletLocalization.string("%lld files created on this device", Int64(urls.count)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(Array(urls.enumerated()), id: \.element.path) { index, url in
                        fileRow(url, index: index)
                        if index < urls.count - 1 { Divider().padding(.leading, 58) }
                    }
                }
                .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 10) {
                    Button { feature.presentShare() } label: {
                        Label(BookletLocalization.string("Share"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("exportResult.share")
                    Button { feature.presentSave() } label: {
                        Label(BookletLocalization.string("Save to Files"), systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("exportResult.save")
                }
                .controlSize(.large)

                Text(BookletLocalization.string("Next steps"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)

                VStack(spacing: 0) {
                    Button {
                        feature.dismissExportResult()
                    } label: {
                        actionRow(BookletLocalization.string("Adjust settings and export again"), icon: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("exportResult.adjustSettings")
                    Divider().padding(.leading, 46)
                    Button {
                        feature.dismissExportResult(selecting: isSplit ? .booklet : .split)
                    } label: {
                        actionRow(isSplit
                                  ? BookletLocalization.string("Make a booklet from this PDF")
                                  : BookletLocalization.string("Split this PDF instead"),
                                  icon: isSplit ? "book.closed" : "scissors")
                    }
                    .accessibilityIdentifier("exportResult.switchTool")
                    Divider().padding(.leading, 46)
                    NavigationLink {
                        BookletHelpMobileView()
                    } label: {
                        actionRow(BookletLocalization.string("View the guide"), icon: "questionmark.circle")
                    }
                    .accessibilityIdentifier("exportResult.viewGuide")
                }
                .buttonStyle(.plain)
                .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
    }

    private func fileRow(_ url: URL, index: Int) -> some View {
        HStack(spacing: 11) {
            PDFDocumentPageView(documentURL: url, pageNumber: 1)
                .frame(width: 34, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(url.lastPathComponent)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(BookletLocalization.string("%@ · %lld pages",
                                               formattedFileSize(url),
                                               Int64(bookletPageCount(for: url) ?? 1)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 2)
            if isSplit, index < feature.viewModel.splitSegments.count {
                Text(feature.viewModel.splitSegments[index].rangeLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookletMobileStyle.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BookletMobileStyle.softAccent, in: Capsule())
            }
        }
        .padding(11)
    }

    private func actionRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .foregroundStyle(BookletMobileStyle.accent)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(13)
        .contentShape(Rectangle())
    }

    private func bookletPageCount(for url: URL) -> Int? {
        PDFDocument(url: url)?.pageCount
    }

    private func formattedFileSize(_ url: URL) -> String {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return "–" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private func failureContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text(BookletLocalization.string("Could not export PDF"))
                .font(.headline)
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
