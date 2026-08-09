import SwiftUI

/// Shared rail for the PDF toolbox. The current document is global while
/// every tool owns an independent settings section and primary action.
struct BookletMakerRailView: View {
    @ObservedObject var viewModel: BookletMakerViewModel
    let onExportBooklet: () -> Void
    let onExportSplit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    toolPicker

                    Divider()

                    railTitle(BookletLocalization.string("Current PDF"))
                    BookletDropZoneView(viewModel: viewModel)

                    Divider()

                    switch viewModel.selectedTool {
                    case .booklet:
                        bookletSettings
                    case .split:
                        splitSettings
                    }
                }
                .padding()
            }

            Divider()
            primaryAction
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var toolPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            railTitle(BookletLocalization.string("PDF Tools"))

            ForEach(PDFTool.allCases) { tool in
                Button {
                    viewModel.selectedTool = tool
                    viewModel.errorMessage = nil
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tool.title)
                                .font(.subheadline.weight(.semibold))
                            Text(tool.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(viewModel.selectedTool == tool
                                  ? Color.accentColor.opacity(0.15)
                                  : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(viewModel.selectedTool == tool
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bookletSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            railTitle(BookletLocalization.string("Booklet Settings"))

            VStack(alignment: .leading, spacing: 4) {
                Text(BookletLocalization.string("Output paper"))
                    .font(.subheadline)
                Picker("", selection: $viewModel.settings.outputPaper) {
                    ForEach(PaperSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(BookletLocalization.string("Layout"))
                    .font(.subheadline)
                Picker("", selection: $viewModel.settings.layout) {
                    Text(BookletLocalization.string("Booklet Fold"))
                        .tag(LayoutMode.bookletFold)
                    Text(BookletLocalization.string("Simple Pair"))
                        .tag(LayoutMode.simplePair)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            settingSlider(
                title: BookletLocalization.string("Margin"),
                value: $viewModel.settings.marginMM
            )
            settingSlider(
                title: BookletLocalization.string("Gutter"),
                value: $viewModel.settings.gutterMM
            )

            Toggle(BookletLocalization.string("Pad with blank page"),
                   isOn: paddingBinding)
                .font(.subheadline)
                .disabled(viewModel.settings.layout == .bookletFold)
            Toggle(BookletLocalization.string("Add cut marks"),
                   isOn: $viewModel.settings.addCutMarks)
                .font(.subheadline)
        }
    }

    private var splitSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            railTitle(BookletLocalization.string("Split Settings"))

            VStack(alignment: .leading, spacing: 5) {
                Text(BookletLocalization.string("Split after these pages"))
                    .font(.subheadline)
                TextField(
                    BookletLocalization.string("For example: 20, 50, 80"),
                    text: $viewModel.splitCutPointsText
                )
                .textFieldStyle(.roundedBorder)

                Text(BookletLocalization.string(
                    "Enter page numbers separated by commas or spaces."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                if let message = viewModel.splitValidationMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(BookletLocalization.string("Split Result"))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(BookletLocalization.string(
                        "%lld PDF files",
                        Int64(viewModel.splitSegments.count)
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                ForEach(Array(viewModel.splitSegments.prefix(6))) { segment in
                    HStack {
                        Text("\(segment.index).")
                            .foregroundStyle(.secondary)
                        Text(BookletLocalization.string(
                            "Split pages %lld–%lld",
                            Int64(segment.startPage),
                            Int64(segment.endPage)
                        ))
                        Spacer()
                        Text(BookletLocalization.string(
                            "%lld pages",
                            Int64(segment.pageCount)
                        ))
                        .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if viewModel.splitSegments.count > 6 {
                    Text(BookletLocalization.string(
                        "And %lld more…",
                        Int64(viewModel.splitSegments.count - 6)
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            if !viewModel.lastSplitOutputURLs.isEmpty {
                Label(
                    BookletLocalization.string(
                        "Exported %lld PDF files",
                        Int64(viewModel.lastSplitOutputURLs.count)
                    ),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)
            }
        }
    }

    private var primaryAction: some View {
        Button(action: primaryActionHandler) {
            HStack {
                Spacer()
                Image(systemName: viewModel.selectedTool == .booklet
                      ? "square.and.arrow.down"
                      : "scissors")
                Text(primaryActionTitle)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canExport)
    }

    private var primaryActionTitle: String {
        switch viewModel.selectedTool {
        case .booklet:
            BookletLocalization.string("Export Booklet PDF")
        case .split:
            BookletLocalization.string(
                "Export %lld PDF files",
                Int64(viewModel.splitSegments.count)
            )
        }
    }

    private func primaryActionHandler() {
        switch viewModel.selectedTool {
        case .booklet: onExportBooklet()
        case .split: onExportSplit()
        }
    }

    private func railTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func settingSlider(title: String,
                               value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(BookletLocalization.string("%lld mm", Int(value.wrappedValue)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0 ... 30, step: 1)
        }
    }

    private var paddingBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.settings.layout == .bookletFold
                    ? true
                    : viewModel.settings.padBlankPage
            },
            set: { viewModel.settings.padBlankPage = $0 }
        )
    }
}

#Preview {
    BookletMakerRailView(
        viewModel: BookletMakerViewModel(),
        onExportBooklet: {},
        onExportSplit: {}
    )
    .frame(width: 280, height: 760)
}
