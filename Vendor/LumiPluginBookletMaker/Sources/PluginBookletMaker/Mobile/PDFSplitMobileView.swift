#if os(iOS)
import SwiftUI

/// Split workflow steps 2–3: choose boundaries, then review generated files.
struct PDFSplitMobileView: View {
    @ObservedObject var feature: BookletMakerMobileFeature
    let onExport: () -> Void
    let onFinish: () -> Void

    private var viewModel: BookletMakerViewModel { feature.viewModel }

    private var outputURLs: [URL]? {
        guard let outcome = feature.exportOutcome,
              case .success(let urls) = outcome else { return nil }
        return urls
    }

    private var isShowingResult: Bool { outputURLs != nil }

    var body: some View {
        VStack(spacing: 0) {
            stageHeader
            Divider()
            if let outputURLs {
                resultContent(outputURLs)
            } else {
                PDFSplitPlanEditorView(viewModel: viewModel)
            }
            Divider()
            bottomBar
        }
        .background(BookletMobileStyle.canvas)
        .navigationTitle(viewModel.currentDocument.baseFileName)
    }

    private var stageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(BookletLocalization.string(isShowingResult ? "Split Result" : "Split Plan"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(BookletLocalization.string("%lld/%lld",
                                               Int64(isShowingResult ? 3 : 2),
                                               Int64(3)))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { step in
                    Capsule()
                        .fill(step <= (isShowingResult ? 3 : 2)
                              ? BookletMobileStyle.accent
                              : BookletMobileStyle.accent.opacity(0.16))
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private func resultContent(_ urls: [URL]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                        outputRow(url, index: index)
                        if index < urls.count - 1 {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 10) {
                    Button { feature.presentShare() } label: {
                        Label(BookletLocalization.string("Share"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button { feature.presentSave() } label: {
                        Label(BookletLocalization.string("Save to Files"), systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding(16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
    }

    private func outputRow(_ url: URL, index: Int) -> some View {
        let segment = index < viewModel.splitSegments.count
            ? viewModel.splitSegments[index]
            : nil

        return HStack(spacing: 11) {
            PDFDocumentPageView(documentURL: url, pageNumber: 1)
                .frame(width: 34, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(url.lastPathComponent)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let segment {
                    Text(BookletLocalization.string("%@ · %lld pages",
                                                   formattedFileSize(url),
                                                   Int64(segment.pageCount)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(segment.rangeLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 2)
        }
        .padding(11)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if viewModel.isBusy {
                ProgressView(value: viewModel.progress)
                HStack {
                    Text(viewModel.isCancelling
                         ? BookletLocalization.string("Cancelling…")
                         : BookletLocalization.string("Generating…"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !viewModel.isCancelling {
                        Button(BookletLocalization.string("Cancel")) { viewModel.cancel() }
                            .font(.footnote)
                    }
                }
            } else if isShowingResult {
                HStack(spacing: 10) {
                    Button {
                        feature.dismissExportResult()
                    } label: {
                        Label(BookletLocalization.string("Previous"), systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("split.stepPrevious")

                    Button(action: onFinish) {
                        Label(BookletLocalization.string("Done"), systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("split.stepDone")
                }
                .controlSize(.large)
            } else {
                HStack(spacing: 10) {
                    Text(BookletLocalization.string("%lld pages · %lld files",
                                                   Int64(viewModel.currentDocument.pageCount),
                                                   Int64(viewModel.splitSegments.count)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Button(action: onExport) {
                        Label(BookletLocalization.string("Split"), systemImage: "scissors")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canExportSplit)
                    .accessibilityIdentifier("split.export")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private func formattedFileSize(_ url: URL) -> String {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return "–" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}
#endif
