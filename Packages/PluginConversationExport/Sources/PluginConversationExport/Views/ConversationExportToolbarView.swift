import SwiftUI
import UniformTypeIdentifiers

struct ConversationExportToolbarView: View {
    @ObservedObject var viewModel: ConversationExportViewModel

    var body: some View {
        Button {
            viewModel.beginExport()
        } label: {
            HStack(spacing: 3) {
                if viewModel.isPreparing {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 10, weight: .medium))
                }
                Text(
                    LumiPluginLocalization.string(
                        viewModel.isPreparing ? "Exporting conversation" : "Export Conversation"
                    )
                )
                .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(Color.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Color.accentColor.opacity(0.22),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canExport)
        .help(Text(LumiPluginLocalization.string("Export current conversation as HTML")))
        .fileExporter(
            isPresented: $viewModel.isExporterPresented,
            document: viewModel.document,
            contentType: .html,
            defaultFilename: viewModel.suggestedFilename,
            onCompletion: viewModel.handleExportCompletion
        )
    }
}
