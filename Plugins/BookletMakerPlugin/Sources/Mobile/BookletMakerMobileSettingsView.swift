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
            settingSection("Output") {
                Picker("Paper Size", selection: $viewModel.settings.outputPaper) {
                    ForEach(PaperSize.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Layout", selection: $viewModel.settings.layout) {
                    Text("Booklet Fold").tag(LayoutMode.bookletFold)
                    Text("Simple Pair").tag(LayoutMode.simplePair)
                }
                .pickerStyle(.segmented)
            }

            settingSection("Spacing") {
                measurementSlider("Margin", value: $viewModel.settings.marginMM)
                measurementSlider("Gutter", value: $viewModel.settings.gutterMM)
            }

            settingSection("Print Options") {
                Toggle("Pad with Blank Page", isOn: paddingBinding)
                    .disabled(viewModel.settings.layout == .bookletFold)
                Toggle("Add Cut Marks", isOn: $viewModel.settings.addCutMarks)
            }
        }
    }

    private var splitSettings: some View {
        Group {
            settingSection("Cut Points") {
                TextField("For example: 20, 50, 80", text: $viewModel.splitCutPointsText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                Text("You can also tap the gaps between page previews.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let message = viewModel.splitValidationMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            settingSection("Result") {
                LabeledContent("Files", value: "\(viewModel.splitSegments.count)")
                LabeledContent("Pages", value: "\(viewModel.currentDocument.pageCount)")
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
            LabeledContent(title, value: "\(Int(value.wrappedValue)) mm")
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
