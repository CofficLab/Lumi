import SwiftUI

// MARK: - Booklet Settings Panel

/// Right-hand side: the imposition parameters and the export button.
struct BookletSettingsPanel: View {

    @ObservedObject var viewModel: BookletMakerViewModel
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(BookletLocalization.string("Settings"))
                .font(.headline)

            // Output paper
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

            // Layout
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

            // Margin
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(BookletLocalization.string("Margin"))
                        .font(.subheadline)
                    Spacer()
                    Text(BookletLocalization.string("%lld mm", Int(viewModel.settings.marginMM)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.settings.marginMM, in: 0...30, step: 1)
            }

            // Gutter
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(BookletLocalization.string("Gutter"))
                        .font(.subheadline)
                    Spacer()
                    Text(BookletLocalization.string("%lld mm", Int(viewModel.settings.gutterMM)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $viewModel.settings.gutterMM, in: 0...30, step: 1)
            }

            // Toggles
            Toggle(BookletLocalization.string("Pad with blank page"),
                   isOn: $viewModel.settings.padBlankPage)
                .font(.subheadline)
            Toggle(BookletLocalization.string("Add cut marks"),
                   isOn: $viewModel.settings.addCutMarks)
                .font(.subheadline)

            Spacer()

            // Export button
            Button(action: onExport) {
                HStack {
                    Spacer()
                    Image(systemName: "square.and.arrow.down")
                    Text(BookletLocalization.string("Export Booklet PDF"))
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canExport)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.06))
        )
    }
}
