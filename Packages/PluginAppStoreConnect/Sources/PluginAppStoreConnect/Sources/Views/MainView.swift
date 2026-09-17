import LumiUI
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var viewModel: VM
    @State private var importingScreenshots = false

    init(viewModel: VM = .shared) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Divider()
            }

            if viewModel.page == .distribution && viewModel.metadataIsDirty {
                TopBar(viewModel: viewModel)
            }

            ZStack {
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewModel.isBusy {
                    ConnectBusyOverlay()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $importingScreenshots,
            allowedContentTypes: [.png, .jpeg],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                viewModel.addScreenshotFiles(urls)
            }
        }
        .task {
            if viewModel.credentials.isComplete && viewModel.apps.isEmpty {
                await viewModel.loadApps(silent: true)
            }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch viewModel.page {
        case .distribution:
            DistributionPage(viewModel: viewModel, importingScreenshots: $importingScreenshots)
        case .xcodeCloud:
            XcodeCloudPage(viewModel: viewModel)
        }
    }
}
