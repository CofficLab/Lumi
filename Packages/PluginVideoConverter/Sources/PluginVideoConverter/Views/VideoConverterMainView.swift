import SwiftUI

/// Main view for the Video Converter plugin.
struct VideoConverterMainView: View {
    @StateObject private var viewModel = VideoConverterViewModel()

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentArea
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "video")
                .font(.title2)
            Text(VideoConverterLocalization.string("Video Converter"))
                .font(.title2.bold())
            Spacer()
        }
        .padding()
    }

    // MARK: - Content

    private var contentArea: some View {
        VStack(spacing: 20) {
            DropZoneView(viewModel: viewModel)
                .padding(.horizontal)
                .padding(.top)

            if let file = viewModel.selectedFile {
                ConversionSettingsView(
                    file: file,
                    outputFormat: $viewModel.outputFormat,
                    isConverting: viewModel.isConverting,
                    progress: viewModel.progress,
                    onConvert: { viewModel.startConversion() },
                    onCancel: { viewModel.cancelConversion() }
                )
                .padding(.horizontal)
            }

            if !viewModel.conversionLog.isEmpty {
                ConversionLogView(log: viewModel.conversionLog)
                    .padding(.horizontal)
                    .padding(.bottom)
            }

            Spacer()
        }
    }
}

#Preview {
    VideoConverterMainView()
        .frame(width: 500, height: 400)
}
