import LumiUI
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var viewModel: ConnectViewModel
    @State private var importingScreenshots = false
    @State private var showingAccountGuide = false

    init(viewModel: ConnectViewModel = .shared) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(viewModel: viewModel)
                .frame(width: 220)
                .layoutPriority(1)

            Divider()

            VStack(spacing: 0) {
                if viewModel.page.showsTopBar {
                    TopBar(viewModel: viewModel)
                }

                if let error = viewModel.errorMessage, shouldShowGlobalError {
                    ErrorBanner(message: error)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    Divider()
                }

                ZStack {
                    pageContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if viewModel.isBusy {
                        AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                            AppLoadingOverlay(size: .small)
                                .frame(width: 80, height: 44)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .sheet(isPresented: $showingAccountGuide) {
            AccountGuideView()
        }
        .task {
            if viewModel.credentials.isComplete && viewModel.apps.isEmpty {
                await viewModel.loadApps()
            }
        }
    }

    private var shouldShowGlobalError: Bool {
        viewModel.page != .distribution
    }

    @ViewBuilder
    private var pageContent: some View {
        switch viewModel.page {
        case .account:
            AccountPage(viewModel: viewModel, showingAccountGuide: $showingAccountGuide)
        case .apps:
            AppsPage(viewModel: viewModel)
        case .distribution:
            DistributionPage(viewModel: viewModel, importingScreenshots: $importingScreenshots)
        case .xcodeCloud:
            XcodeCloudPage(viewModel: viewModel)
        }
    }
}
