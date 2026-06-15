import LumiUI
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var viewModel: AppStoreConnectViewModel
    @State private var importingScreenshots = false
    @State private var showingAccountGuide = false

    init(viewModel: AppStoreConnectViewModel = .shared) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        HStack(spacing: 0) {
            navigation
                .frame(width: 220)
                .background(.regularMaterial)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

    private var navigation: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppStoreConnectLocalization.string("App Store"))
                    .font(.title3.weight(.semibold))
                Text(viewModel.connectionStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding()

            Divider()

            navigationSection(AppStoreConnectLocalization.string("General"), pages: AppStoreConnectViewModel.generalPages)

            Divider()
                .padding(.vertical, 8)

            navigationSection(AppStoreConnectLocalization.string("Current App"), pages: AppStoreConnectViewModel.appPages)

            Spacer()
        }
    }

    private func navigationSection(_ title: String, pages: [AppStoreConnectViewModel.Page]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            ForEach(pages) { page in
                Button {
                    viewModel.navigate(to: page)
                } label: {
                    Label(page.title, systemImage: page.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(pages == AppStoreConnectViewModel.appPages && viewModel.selectedApp == nil)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(viewModel.page == page ? Color.accentColor.opacity(0.16) : Color.clear)
                .opacity(pages == AppStoreConnectViewModel.appPages && viewModel.selectedApp == nil ? 0.45 : 1)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            contextBar
            Divider()

            if let error = viewModel.errorMessage, viewModel.page != .screenshots {
                ErrorBanner(message: error)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Divider()
            }

            ZStack {
                switch viewModel.page {
                case .account:
                    AccountPage(viewModel: viewModel, showingAccountGuide: $showingAccountGuide)
                case .apps:
                    AppsPage(viewModel: viewModel)
                case .versions:
                    VersionsPage(viewModel: viewModel)
                case .metadata:
                    MetadataPage(viewModel: viewModel)
                case .screenshots:
                    ScreenshotsPage(viewModel: viewModel, importingScreenshots: $importingScreenshots)
                case .xcodeCloud:
                    XcodeCloudPage(viewModel: viewModel)
                }

                if viewModel.isBusy {
                    AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                        AppLoadingOverlay(size: .small)
                            .frame(width: 80, height: 44)
                    }
                }
            }
        }
    }

    private var contextBar: some View {
        HStack(spacing: 12) {
            switch viewModel.page {
            case .account, .apps:
                if let app = viewModel.selectedApp {
                    IconView(url: app.iconURL, size: 20)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(app.name)
                            .lineLimit(1)
                        Text(app.bundleID)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(AppStoreConnectLocalization.string("No App Selected"))
                        .foregroundStyle(.secondary)
                }
            default:
                Text(viewModel.selectedVersion?.versionString ?? AppStoreConnectLocalization.string("No Version"))
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedLocalization?.locale ?? AppStoreConnectLocalization.string("No Locale"))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            AppButton(AppStoreConnectLocalization.string("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                Task { await viewModel.refreshCurrentPage() }
            }
            .disabled(!viewModel.credentials.isComplete || viewModel.isBusy)
        }
        .font(.caption)
        .padding(.horizontal)
        .frame(height: 44)
    }
}
