import SwiftUI

/// Center toolbar tabs for switching between PDF tools.
struct BookletMakerToolbarToolTabsView: View {
    @ObservedObject var viewModel: BookletMakerViewModel
    @State private var selectedTool: PDFTool

    init(viewModel: BookletMakerViewModel) {
        self.viewModel = viewModel
        _selectedTool = State(initialValue: viewModel.selectedTool)
    }

    var body: some View {
        Picker(BookletLocalization.string("PDF Tools"), selection: $selectedTool) {
            ForEach(PDFTool.displayOrder) { tool in
                Label(tool.title, systemImage: tool.systemImage)
                    .tag(tool)
                    .accessibilityIdentifier("pdfTool.\(tool.id)")
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.regular)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityIdentifier("pdfToolPicker")
        .onChange(of: selectedTool) { tool in
            guard viewModel.selectedTool != tool else { return }
            viewModel.selectedTool = tool
        }
        .onChange(of: viewModel.selectedTool) { tool in
            guard selectedTool != tool else { return }
            selectedTool = tool
        }
    }
}
