#if os(iOS)
import SwiftUI

/// Booklet 原生参数面板：输出纸张与布局、边距/装订线、裁切与补白选项。
/// 所有控件直接绑定共享 `BookletSettings`，改动即时反映到拼版预览。
struct BookletParameterPanelView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                outputSection
                spacingSection
                printOptionsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Output

    private var outputSection: some View {
        parameterSection(BookletLocalization.string("Output")) {
            HStack {
                Label(BookletLocalization.string("Paper"), systemImage: "rectangle.portrait.on.rectangle.portrait")
                Spacer()
                Picker(BookletLocalization.string("Paper"), selection: $viewModel.settings.outputPaper) {
                    ForEach(PaperSize.allCases) { paper in
                        Text(paper.displayName).tag(paper)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Label(BookletLocalization.string("Layout"), systemImage: "rectangle.split.2x1")
                Spacer()
                Picker(BookletLocalization.string("Layout"), selection: $viewModel.settings.layout) {
                    Text(BookletLocalization.string("Booklet Fold")).tag(LayoutMode.bookletFold)
                    Text(BookletLocalization.string("Simple Pair")).tag(LayoutMode.simplePair)
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - Spacing

    private var spacingSection: some View {
        parameterSection(BookletLocalization.string("Spacing")) {
            measurementSlider(
                BookletLocalization.string("Margin"),
                value: $viewModel.settings.marginMM
            )
            measurementSlider(
                BookletLocalization.string("Gutter"),
                value: $viewModel.settings.gutterMM
            )
        }
    }

    // MARK: - Print options

    private var printOptionsSection: some View {
        parameterSection(BookletLocalization.string("Print Options")) {
            Toggle(isOn: $viewModel.settings.addCutMarks) {
                Label(BookletLocalization.string("Add cut marks"), systemImage: "scissors")
            }
            .tint(.accentColor)

            Toggle(isOn: $viewModel.settings.padBlankPage) {
                Label(BookletLocalization.string("Pad with blank page"), systemImage: "plus.rectangle.on.rectangle")
            }
            .tint(.accentColor)
            .disabled(viewModel.settings.layout == .bookletFold)
        }
    }

    // MARK: - Helpers

    private func parameterSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func measurementSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(BookletLocalization.string("%lld mm", Int64(value.wrappedValue)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0 ... 30, step: 1)
                .accessibilityLabel(title)
        }
    }
}
#endif
