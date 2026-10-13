import SwiftUI

/// Workspace for ordering and merging several PDF files.
struct PDFMergeWorkspaceView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BookletLocalization.string("Merge PDF Files"))
                        .font(.title2.weight(.semibold))
                    Text(BookletLocalization.string(
                        "Arrange the files, then export one combined PDF."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Label(
                    BookletLocalization.string(
                        "%lld files · %lld pages",
                        Int64(viewModel.mergeDocuments.count),
                        Int64(viewModel.mergePageCount)
                    ),
                    systemImage: "doc.on.doc"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            if viewModel.mergeDocuments.isEmpty {
                ContentUnavailableView {
                    Label(BookletLocalization.string("No PDF files selected"), systemImage: "doc.badge.plus")
                } description: {
                    Text(BookletLocalization.string("Choose or drop at least two PDF files to begin."))
                }
            } else {
                List {
                    ForEach(Array(viewModel.mergeDocuments.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Image(systemName: "doc.fill")
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.url.lastPathComponent)
                                    .lineLimit(1)
                                Text(BookletLocalization.string("%lld pages", Int64(item.pageCount)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button(BookletLocalization.string("Move up"), systemImage: "chevron.up") {
                                viewModel.moveMergeDocument(item, offsetBy: -1)
                            }
                            .disabled(index == 0)
                            Button(BookletLocalization.string("Move down"), systemImage: "chevron.down") {
                                viewModel.moveMergeDocument(item, offsetBy: 1)
                            }
                            .disabled(index == viewModel.mergeDocuments.count - 1)
                            Button(BookletLocalization.string("Remove"), systemImage: "trash", role: .destructive) {
                                viewModel.removeMergeDocument(item)
                            }
                        }
                    }
                    .onMove { offsets, destination in
                        viewModel.moveMergeDocuments(from: offsets, to: destination)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
