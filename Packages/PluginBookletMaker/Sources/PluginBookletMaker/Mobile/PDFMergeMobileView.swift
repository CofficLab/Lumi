#if os(iOS)
import SwiftUI

struct PDFMergeMobileView: View {
    @ObservedObject var viewModel: BookletMakerViewModel
    let onOpenPDF: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(viewModel.mergeDocuments) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.url.lastPathComponent)
                                    .lineLimit(1)
                                Text(BookletLocalization.string("%lld pages", Int64(item.pageCount)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.removeMergeDocument(item)
                            } label: {
                                Label(BookletLocalization.string("Remove"), systemImage: "trash")
                            }
                        }
                    }
                    .onMove { offsets, destination in
                        viewModel.moveMergeDocuments(from: offsets, to: destination)
                    }
                } header: {
                    Text(BookletLocalization.string("Merge order"))
                }
            }
            .environment(\.editMode, .constant(.active))

            Divider()
            VStack(spacing: 8) {
                Text(BookletLocalization.string(
                    "%lld files · %lld pages",
                    Int64(viewModel.mergeDocuments.count),
                    Int64(viewModel.mergePageCount)
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(action: onOpenPDF) {
                        Label(BookletLocalization.string("Add PDFs"), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    Button(action: onExport) {
                        Label(BookletLocalization.string("Merge"), systemImage: "arrow.triangle.merge")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canExportMerge)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .navigationTitle(BookletLocalization.string("Merge PDF"))
    }
}
#endif
