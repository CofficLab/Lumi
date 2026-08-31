#if os(iOS)
import LumiUI
import SwiftUI

struct BookletMakerMobileSettingsView: View {
    @LumiTheme private var theme

    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            switch viewModel.selectedTool {
            case .booklet: bookletSettings
            case .split: splitSettings
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bookletSettings: some View {
        Group {
            settingSection(BookletLocalization.string("Output")) {
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
            }

            settingSection(BookletLocalization.string("Spacing")) {
                measurementSlider(BookletLocalization.string("Margin"),
                                  value: $viewModel.settings.marginMM)
                measurementSlider(BookletLocalization.string("Gutter"),
                                  value: $viewModel.settings.gutterMM)
            }

            settingSection(BookletLocalization.string("Print Options")) {
                AppSettingRow(title: BookletLocalization.string("Pad with blank page")) {
                    Toggle("", isOn: paddingBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(viewModel.settings.layout == .bookletFold)
                }
                AppSettingToggleRow(
                    BookletLocalization.string("Add cut marks"),
                    isOn: $viewModel.settings.addCutMarks
                )
            }
        }
    }

    private var splitSettings: some View {
        Group {
            settingSection(BookletLocalization.string("Cut Points")) {
                AppInputField(
                    LocalizedStringKey(BookletLocalization.string("For example: 20, 50, 80")),
                    text: $viewModel.splitCutPointsText
                )
                    .keyboardType(.numbersAndPunctuation)
                Text(BookletLocalization.string("You can also tap the gaps between page previews."))
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(theme.textSecondary)
                if let message = viewModel.splitValidationMessage {
                    AppErrorBanner(message: LocalizedStringKey(message))
                }
            }

            settingSection(BookletLocalization.string("Result")) {
                AppSettingRow(title: BookletLocalization.string("Files")) {
                    AppTag("\(viewModel.splitSegments.count)", style: .accent)
                }
                AppSettingRow(title: BookletLocalization.string("Pages")) {
                    AppTag("\(viewModel.currentDocument.pageCount)")
                }
            }
        }
    }

    private func settingSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        AppSettingSection(title: title) {
            content()
        }
    }

    private func measurementSlider(_ title: String, value: Binding<Double>) -> some View {
        AppSettingRow(
            title: title,
            description: BookletLocalization.string("%lld mm", Int64(value.wrappedValue))
        ) {
            Slider(value: value, in: 0 ... 30, step: 1)
                .frame(minWidth: 130)
        }
    }

    private var paddingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.layout == .bookletFold || viewModel.settings.padBlankPage },
            set: { viewModel.settings.padBlankPage = $0 }
        )
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
}
#endif
