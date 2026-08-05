import SwiftUI

/// Top-level screen shown inside the view container.
struct ImageToPDFMainView: View {
    @StateObject private var viewModel = ImageToPDFViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    inputSection
                    actionBar
                    outputSection
                }
                .padding()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2)
            Text(ImageToPDFLocalization.string("Image to PDF"))
                .font(.title2.bold())
            Spacer()
        }
        .padding()
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ImageDropZoneView(viewModel: viewModel)

            if !viewModel.inputImages.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.inputImages) { item in
                        ImageListRow(item: item) {
                            viewModel.removeImage(item)
                        }
                        if item.id != viewModel.inputImages.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.05))
                )
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            Button(action: { viewModel.pickImages() }) {
                Label(
                    ImageToPDFLocalization.string("Add files"),
                    systemImage: "plus"
                )
            }
            .buttonStyle(.bordered)

            Spacer()

            if viewModel.isConverting {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 6)
            }

            Button {
                viewModel.convertAll()
            } label: {
                Label(
                    ImageToPDFLocalization.string("Convert"),
                    systemImage: "arrow.right.circle.fill"
                )
                .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.inputImages.isEmpty || viewModel.isConverting)
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(ImageToPDFLocalization.string("PDFs"))
                    .font(.headline)
                Spacer()
                if let message = viewModel.lastErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
                Button {
                    viewModel.chooseDirectoryAndExport()
                } label: {
                    Label(
                        ImageToPDFLocalization.string("Export to…"),
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(!hasSuccessfulOutput)

                Button(role: .destructive) {
                    viewModel.clearAll()
                } label: {
                    Label(
                        ImageToPDFLocalization.string("Clear"),
                        systemImage: "trash"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.outputItems.isEmpty)
            }

            if viewModel.outputItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(ImageToPDFLocalization.string("No PDFs yet"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.05))
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.outputItems) { item in
                        PDFOutputRow(
                            item: item,
                            onReveal: { viewModel.revealInFinder(item) },
                            onOpen: { viewModel.openInPreview(item) },
                            onRemove: { viewModel.removeOutput(item) }
                        )
                        if item.id != viewModel.outputItems.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.05))
                )
            }
        }
    }

    private var hasSuccessfulOutput: Bool {
        viewModel.outputItems.contains { $0.status.outputURL != nil }
    }
}

#Preview {
    ImageToPDFMainView()
        .frame(width: 560, height: 600)
}
