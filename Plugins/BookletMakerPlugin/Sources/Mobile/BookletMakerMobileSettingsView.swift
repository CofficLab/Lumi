#if os(iOS)
import SwiftUI

struct BookletMakerMobileSettingsView: View {
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
                Picker(BookletLocalization.string("Output paper"),
                       selection: $viewModel.settings.outputPaper) {
                    ForEach(PaperSize.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker(BookletLocalization.string("Layout"), selection: $viewModel.settings.layout) {
                    Text(BookletLocalization.string("Booklet Fold")).tag(LayoutMode.bookletFold)
                    Text(BookletLocalization.string("Simple Pair")).tag(LayoutMode.simplePair)
                }
                .pickerStyle(.segmented)
            }

            settingSection(BookletLocalization.string("Spacing")) {
                measurementSlider(BookletLocalization.string("Margin"),
                                  value: $viewModel.settings.marginMM)
                measurementSlider(BookletLocalization.string("Gutter"),
                                  value: $viewModel.settings.gutterMM)
            }

            settingSection(BookletLocalization.string("Print Options")) {
                Toggle(BookletLocalization.string("Pad with blank page"), isOn: paddingBinding)
                    .disabled(viewModel.settings.layout == .bookletFold)
                Toggle(BookletLocalization.string("Add cut marks"),
                       isOn: $viewModel.settings.addCutMarks)
            }
        }
    }

    private var splitSettings: some View {
        Group {
            settingSection(BookletLocalization.string("Cut Points")) {
                TextField(BookletLocalization.string("For example: 20, 50, 80"),
                          text: $viewModel.splitCutPointsText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                Text(BookletLocalization.string("You can also tap the gaps between page previews."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let message = viewModel.splitValidationMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            settingSection(BookletLocalization.string("Result")) {
                LabeledContent(BookletLocalization.string("Files"),
                               value: "\(viewModel.splitSegments.count)")
                LabeledContent(BookletLocalization.string("Pages"),
                               value: "\(viewModel.currentDocument.pageCount)")
            }
        }
    }

    private func settingSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            content()
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func measurementSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(spacing: 8) {
            LabeledContent(
                title,
                value: BookletLocalization.string("%lld mm", Int64(value.wrappedValue))
            )
            Slider(value: value, in: 0 ... 30, step: 1)
        }
    }

    private var paddingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.layout == .bookletFold || viewModel.settings.padBlankPage },
            set: { viewModel.settings.padBlankPage = $0 }
        )
    }
}
#endif
