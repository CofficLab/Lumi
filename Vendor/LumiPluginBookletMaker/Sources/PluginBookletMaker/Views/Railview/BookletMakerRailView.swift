import LumiUI
import SwiftUI
import BookletMakerCore

/// Shared rail for the PDF toolbox. The current document is global while
/// every tool owns an independent settings section and primary action.
struct BookletMakerRailView: View {
    @LumiTheme private var theme

    @ObservedObject var viewModel: BookletMakerViewModel
    let onExportBooklet: () -> Void
    let onExportSplit: () -> Void
    let onExportMerge: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    toolPicker

                    AppDivider()

                    BookletDropZoneView(viewModel: viewModel)

                    AppDivider()

                    switch viewModel.selectedTool {
                    case .booklet:
                        bookletSettings
                    case .split:
                        splitSettings
                    case .merge:
                        mergeSettings
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
                .accessibilityIdentifier("overview.\(tool.id)Tool")
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
                // 锚点挂在 segmented control 的外层：按「行标题 + 选项文字」定位，
                // 比按 SF Symbol 或控件序号定位更稳定。
                .accessibilityIdentifier("booklet.outputPaper")
            }

            AppSettingRow(title: BookletLocalization.string("Layout")) {
                AppSegmentedControl(
                    [
                        BookletLocalization.string("Booklet Fold"),
                        BookletLocalization.string("Sectioned Booklet"),
                        BookletLocalization.string("Simple Pair")
                    ],
                    selection: layoutSelection
                )
                .accessibilityIdentifier("booklet.layoutPicker")
            }

            // 分册版式才需要「每册页数」：折叠版式固定 4 页一册，
            // 简单并排根本不分组。
            if viewModel.settings.layout == .signatureFold {
                AppSettingRow(
                    title: BookletLocalization.string("Pages per signature")
                ) {
                    Picker(
                        BookletLocalization.string("Pages per signature"),
                        selection: $viewModel.settings.signaturePageCount
                    ) {
                        ForEach(BookletSettings.signaturePageCountOptions, id: \.self) { count in
                            Text(BookletLocalization.string("%lld pages", Int64(count)))
                                .tag(count)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .accessibilityIdentifier("booklet.signaturePages")
                }
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
                    .accessibilityIdentifier("booklet.padBlankPage")
            }
            AppSettingToggleRow(
                BookletLocalization.string("Add cut marks"),
                isOn: $viewModel.settings.addCutMarks
            )
            .accessibilityIdentifier("booklet.addCutMarks")
        }
        .accessibilityIdentifier("booklet.settings")
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
                .accessibilityIdentifier("split.cutPointsInput")
            }

            if let message = viewModel.splitValidationMessage ?? viewModel.splitFileNameValidationMessage {
                AppErrorBanner(message: LocalizedStringKey(message))
                    .accessibilityIdentifier("split.validationError")
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
                        .accessibilityIdentifier("split.summary")
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

    private var mergeSettings: some View {
        AppSettingSection(title: BookletLocalization.string("Merge Settings")) {
            AppCard(
                style: .subtle,
                cornerRadius: DesignTokens.Radius.sm,
                padding: DesignTokens.Spacing.compactPadding,
                showShadow: false
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(BookletLocalization.string("Merge Result"))
                        .font(DesignTokens.Typography.bodyEmphasized)
                    Text(BookletLocalization.string(
                        "%lld files · %lld pages",
                        Int64(viewModel.mergeDocuments.count),
                        Int64(viewModel.mergePageCount)
                    ))
                    .font(DesignTokens.Typography.caption1)
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityIdentifier("merge.summary")
                    if viewModel.mergeDocuments.count < 2 {
                        Text(BookletLocalization.string("Select at least two PDF files to merge."))
                            .font(DesignTokens.Typography.caption1)
                            .foregroundStyle(theme.textSecondary)
                            .accessibilityIdentifier("merge.insufficientHint")
                    }
                }
                // 不在此处打 `merge.settingsCard` 锚点：SwiftUI 会把祖先
                // identifier 下推到叶子，覆盖掉 `merge.summary` 与
                // `merge.insufficientHint`。卡片是否出现改用 `merge.summary` 判定。
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
                    : (viewModel.selectedTool == .split
                        ? "scissors"
                        : "arrow.triangle.merge")),
            style: .primary,
            fillsWidth: true,
            action: primaryActionHandler
        )
        .disabled(!viewModel.isBusy && !viewModel.canExport)
        .accessibilityIdentifier("workspace.primaryAction")
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
        case .merge:
            return BookletLocalization.string("Export Merged PDF")
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
        case .merge: onExportMerge()
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
                .accessibilityIdentifier("booklet.slider.\(sliderIdentifier(for: title))")
                .accessibilityValue(String(Int(value.wrappedValue)))
        }
    }

    /// 把本地化行标题折叠成稳定的锚点后缀。
    ///
    /// 行标题会随语言变化，不能直接进 identifier；这里对已知取值做映射，
    /// 未命中时退化为去空格小写，保证 identifier 在各语言下保持一致，
    /// 不会因切换系统语言而改变 AX 树结构。
    private func sliderIdentifier(for title: String) -> String {
        switch title {
        case BookletLocalization.string("Margin"): return "margin"
        case BookletLocalization.string("Gutter"): return "gutter"
        default: return title.lowercased().replacingOccurrences(of: " ", with: "")
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

    /// 版式分段控件的选中项。
    ///
    /// 控件顺序是「折叠 / 分册 / 简单并排」，与 `LayoutMode` 的取值一一对应，
    /// 因此用下标而不是枚举本身来桥接。
    private var layoutSelection: Binding<Int> {
        Binding(
            get: {
                switch viewModel.settings.layout {
                case .bookletFold: 0
                case .signatureFold: 1
                case .simplePair: 2
                }
            },
            set: { index in
                switch index {
                case 0: viewModel.settings.layout = .bookletFold
                case 1: viewModel.settings.layout = .signatureFold
                default: viewModel.settings.layout = .simplePair
                }
            }
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
        onExportSplit: {},
        onExportMerge: {}
    )
    .frame(width: 280, height: 760)
}
