import LumiUI
import SwiftUI

/// Shared rail for the PDF toolbox. The current document is global while
/// every tool owns an independent settings section and primary action.
struct BookletMakerRailView: View {
    @LumiTheme private var theme

    @ObservedObject var viewModel: BookletMakerViewModel
    let onExportBooklet: () -> Void
    let onExportSplit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    toolPicker

                    AppDivider()

                    railTitle(BookletLocalization.string("Current PDF"))
                    BookletDropZoneView(viewModel: viewModel)

                    AppDivider()

                    switch viewModel.selectedTool {
                    case .booklet:
                        bookletSettings
                    case .split:
                        splitSettings
                    }
                }
                .padding()
            }

            AppDivider()
            if viewModel.isBusy {
                BookletProgressView(viewModel: viewModel)
                    .padding(.horizontal)
                    .padding(.top, 10)
            }
            primaryAction
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var toolPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            railTitle(BookletLocalization.string("PDF Tools"))

            ForEach(PDFTool.displayOrder) { tool in
                AppListRow(
                    isSelected: viewModel.selectedTool == tool,
                    action: {
                        viewModel.selectedTool = tool
                        viewModel.errorMessage = nil
                    }
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tool.title)
                                .font(DesignTokens.Typography.subheadline)
                                .fontWeight(.semibold)
                            Text(tool.subtitle)
                                .font(DesignTokens.Typography.caption1)
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(DesignTokens.Typography.caption1)
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.textTertiary)
                    }
                    .foregroundStyle(theme.textPrimary)
                }
            }
        }
    }

    private var bookletSettings: some View {
        AppSettingSection(title: BookletLocalization.string("Booklet Settings")) {
            AppSettingRow(title: BookletLocalization.string("Output paper")) {
                AppSegmentedControl(
                    PaperSize.allCases.map(\.displayName),
                    selection: paperSizeSelection
                )
            }

            AppSettingRow(title: BookletLocalization.string("Layout")) {
                AppSegmentedControl(
                    [
                        BookletLocalization.string("Booklet Fold"),
                        BookletLocalization.string("Simple Pair")
                    ],
                    selection: layoutSelection
                )
            }

            settingSlider(
                title: BookletLocalization.string("Margin"),
                value: $viewModel.settings.marginMM
            )
            settingSlider(
                title: BookletLocalization.string("Gutter"),
                value: $viewModel.settings.gutterMM
            )

            AppSettingRow(title: BookletLocalization.string("Pad with blank page")) {
                Toggle("", isOn: paddingBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(viewModel.settings.layout == .bookletFold)
            }
            AppSettingToggleRow(
                BookletLocalization.string("Add cut marks"),
                isOn: $viewModel.settings.addCutMarks
            )
        }
    }

    private var splitSettings: some View {
        AppSettingSection(title: BookletLocalization.string("Split Settings")) {
            AppSettingRow(
                title: BookletLocalization.string("Split after these pages"),
                description: BookletLocalization.string(
                    "Enter page numbers separated by commas or spaces."
                )
            ) {
                AppInputField(
                    LocalizedStringKey(BookletLocalization.string("For example: 20, 50, 80")),
                    text: $viewModel.splitCutPointsText
                )
            }

            if let message = viewModel.splitValidationMessage ?? viewModel.splitFileNameValidationMessage {
                AppErrorBanner(message: LocalizedStringKey(message))
            }

            AppCard(
                style: .subtle,
                cornerRadius: DesignTokens.Radius.sm,
                padding: DesignTokens.Spacing.compactPadding,
                showShadow: false
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(BookletLocalization.string("Split Result"))
                            .font(DesignTokens.Typography.bodyEmphasized)
                        Spacer()
                        AppTag(BookletLocalization.string(
                            "%lld PDF files",
                            Int64(viewModel.splitSegments.count)
                        ))
                    }

                    ForEach(Array(viewModel.splitSegments.prefix(6))) { segment in
                        HStack {
                            Text("\(segment.index).")
                                .foregroundStyle(theme.textSecondary)
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
                            .foregroundStyle(theme.textSecondary)
                        }
                        .font(DesignTokens.Typography.caption1)
                    }

                    if viewModel.splitSegments.count > 6 {
                        Text(BookletLocalization.string(
                            "And %lld more…",
                            Int64(viewModel.splitSegments.count - 6)
                        ))
                        .font(DesignTokens.Typography.caption1)
                        .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            if !viewModel.lastSplitOutputURLs.isEmpty {
                Label(
                    BookletLocalization.string(
                        "Exported %lld PDF files",
                        Int64(viewModel.lastSplitOutputURLs.count)
                    ),
                    systemImage: "checkmark.circle.fill"
                )
                .font(DesignTokens.Typography.caption1)
                .foregroundStyle(theme.success)
            }
        }
    }

    private var primaryAction: some View {
        AppButton(
            primaryActionTitle,
            systemImage: viewModel.isBusy
                ? "xmark.circle"
                : (viewModel.selectedTool == .booklet
                    ? "square.and.arrow.down"
                    : "scissors"),
            style: .primary,
            fillsWidth: true,
            action: primaryActionHandler
        )
        .disabled(!viewModel.isBusy && !viewModel.canExport)
    }

    private var primaryActionTitle: String {
        if viewModel.isPreparingPreview {
            return BookletLocalization.string("Preparing preview…")
        }
        if viewModel.isRendering {
            return BookletLocalization.string("Cancel Export")
        }
        switch viewModel.selectedTool {
        case .booklet:
            return BookletLocalization.string("Export Booklet PDF")
        case .split:
            return BookletLocalization.string(
                "Export %lld PDF files",
                Int64(viewModel.splitSegments.count)
            )
        }
    }

    private func primaryActionHandler() {
        if viewModel.isBusy {
            viewModel.cancel()
            return
        }
        switch viewModel.selectedTool {
        case .booklet: onExportBooklet()
        case .split: onExportSplit()
        }
    }

    private func railTitle(_ title: String) -> some View {
        Text(title)
            .font(DesignTokens.Typography.title3)
            .foregroundStyle(theme.textPrimary)
    }

    private func settingSlider(title: String,
                               value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(DesignTokens.Typography.subheadline)
                Spacer()
                Text(BookletLocalization.string("%lld mm", Int(value.wrappedValue)))
                    .font(DesignTokens.Typography.caption1)
                    .foregroundStyle(theme.textSecondary)
            }
            Slider(value: value, in: 0 ... 30, step: 1)
        }
    }

    private var paperSizeSelection: Binding<Int> {
        Binding(
            get: { PaperSize.allCases.firstIndex(of: viewModel.settings.outputPaper) ?? 0 },
            set: { index in
                guard PaperSize.allCases.indices.contains(index) else { return }
                viewModel.settings.outputPaper = PaperSize.allCases[index]
            }
        )
    }

    private var layoutSelection: Binding<Int> {
        Binding(
            get: { viewModel.settings.layout == .bookletFold ? 0 : 1 },
            set: { viewModel.settings.layout = $0 == 0 ? .bookletFold : .simplePair }
        )
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
