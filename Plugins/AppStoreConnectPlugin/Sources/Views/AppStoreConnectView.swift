import LumiUI
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppStoreConnectView: View {
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
            AppStoreConnectAccountGuideView()
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

            if let error = viewModel.errorMessage {
                AppStoreConnectErrorBanner(message: error)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Divider()
            }

            ZStack {
                switch viewModel.page {
                case .account:
                    accountPage
                case .apps:
                    appsPage
                case .versions:
                    versionsPage
                case .metadata:
                    metadataPage
                case .screenshots:
                    screenshotsPage
                case .xcodeCloud:
                    xcodeCloudPage
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
                    AppStoreIconView(url: app.iconURL, size: 20)
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
                Task {
                    switch viewModel.page {
                    case .account:
                        await viewModel.testConnection()
                    case .apps:
                        await viewModel.loadApps()
                    case .versions:
                        await viewModel.loadVersions()
                    case .metadata:
                        await viewModel.loadLocalizations()
                    case .screenshots:
                        await viewModel.loadScreenshotSets()
                    case .xcodeCloud:
                        if viewModel.selectedCiWorkflow != nil {
                            await viewModel.loadSelectedCiWorkflowDetail()
                        } else if viewModel.selectedCiProduct != nil {
                            await viewModel.loadCiWorkflows()
                        } else {
                            await viewModel.loadCiProducts()
                        }
                    }
                }
            }
            .disabled(!viewModel.credentials.isComplete || viewModel.isBusy)
        }
        .font(.caption)
        .padding(.horizontal)
        .frame(height: 44)
    }

    private var accountPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppStoreConnectLocalization.string("Need an App Store Connect API key?"))
                                .font(.headline)
                            Text(AppStoreConnectLocalization.string("Open the setup guide for where to find Issuer ID, Key ID, and the .p8 private key."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        AppButton(AppStoreConnectLocalization.string("Setup Guide"), systemImage: "book", size: .small) {
                            showingAccountGuide = true
                        }
                    }
                }

                AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppStoreConnectLocalization.string("Global API Key"))
                            .font(.headline)

                        GlassTextField(title: AppStoreConnectLocalization.string("Issuer ID"), text: $viewModel.credentials.issuerID)
                        GlassTextField(title: AppStoreConnectLocalization.string("Key ID"), text: $viewModel.credentials.keyID)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppStoreConnectLocalization.string("Private Key (.p8)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $viewModel.credentials.privateKey)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 140)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.25))
                                )
                            if viewModel.hasStoredPrivateKey {
                                Text(AppStoreConnectLocalization.string("A private key is stored in Keychain. Saving replaces it."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                    HStack {
                        AppButton(AppStoreConnectLocalization.string("Save Credentials"), systemImage: "key.fill", style: .primary) {
                            viewModel.saveCredentials()
                        }

                        AppButton(AppStoreConnectLocalization.string("Test Connection"), systemImage: "network") {
                            Task { await viewModel.testConnection() }
                        }
                        .disabled(!viewModel.credentials.isComplete)

                        AppButton(AppStoreConnectLocalization.string("Disconnect"), systemImage: "xmark.circle", style: .destructive) {
                            viewModel.disconnect()
                        }

                        Spacer()
                        Text(viewModel.connectionStatus)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }

    private var appsPage: some View {
        VStack(spacing: 0) {
            pageHeader(
                title: AppStoreConnectLocalization.string("Apps"),
                subtitle: AppStoreConnectLocalization.string("Browse and select an App Store Connect app")
            )

            HStack {
                AppSearchBar(text: $viewModel.searchText, placeholder: LocalizedStringKey(AppStoreConnectLocalization.string("Search by name, bundle ID, or SKU")))
                    .frame(maxWidth: 420)

                AppButton(AppStoreConnectLocalization.string("Load Apps"), systemImage: "square.and.arrow.down", size: .small) {
                    Task { await viewModel.loadApps() }
                }
                .disabled(!viewModel.credentials.isComplete)

                Spacer()
            }
            .padding()

            if viewModel.filteredApps.isEmpty {
                AppEmptyState(
                    icon: "square.grid.2x2",
                    title: AppStoreConnectLocalization.string("No Apps"),
                    description: viewModel.credentials.isComplete
                        ? AppStoreConnectLocalization.string("Load apps from App Store Connect or adjust your search.")
                        : AppStoreConnectLocalization.string("Configure API credentials on the Account page first.")
                )
            } else {
                List(selection: Binding(
                    get: { viewModel.selectedApp?.id },
                    set: { id in
                        if let id, let app = viewModel.apps.first(where: { $0.id == id }) {
                            viewModel.selectApp(app)
                        }
                    }
                )) {
                    ForEach(viewModel.filteredApps) { app in
                        AppStoreAppRow(app: app)
                            .tag(app.id)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var versionsPage: some View {
        VStack(spacing: 0) {
            pageHeader(
                title: AppStoreConnectLocalization.string("Versions"),
                subtitle: viewModel.selectedApp.map { AppStoreConnectLocalization.string("App Store versions for %@", $0.name) } ?? AppStoreConnectLocalization.string("Select an app first")
            )

            List(selection: Binding(
                get: { viewModel.selectedVersion?.id },
                set: { id in
                    if let id, let version = viewModel.versions.first(where: { $0.id == id }) {
                        viewModel.selectVersion(version)
                    }
                }
            )) {
                ForEach(viewModel.versions) { version in
                    AppStoreVersionRow(version: version)
                        .tag(version.id)
                }
            }
            .listStyle(.inset)
        }
    }

    private var metadataPage: some View {
        VStack(spacing: 0) {
            pageHeader(title: AppStoreConnectLocalization.string("Metadata"), subtitle: AppStoreConnectLocalization.string("Edit App Store version localization fields"))

            if viewModel.localizations.isEmpty {
                AppEmptyState(
                    icon: "text.badge.xmark",
                    title: AppStoreConnectLocalization.string("No Localizations"),
                    description: AppStoreConnectLocalization.string("Select a version and refresh metadata to load localizations.")
                )
            } else {
                HStack {
                    Picker(AppStoreConnectLocalization.string("Locale"), selection: Binding(
                        get: { viewModel.selectedLocalizationID ?? "" },
                        set: { viewModel.selectLocalization(id: $0) }
                    )) {
                        ForEach(viewModel.localizations) { localization in
                            Text(localization.locale).tag(localization.id)
                        }
                    }
                    .frame(width: 220)

                    Spacer()

                    if viewModel.metadataIsDirty {
                        Text(AppStoreConnectLocalization.string("Unsaved changes"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    AppButton(AppStoreConnectLocalization.string("Save Metadata"), systemImage: "square.and.arrow.down", style: .primary, size: .small) {
                        Task { await viewModel.saveMetadata() }
                    }
                    .disabled(!viewModel.metadataIsDirty)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                MetadataEditor(viewModel: viewModel)
            }
        }
    }

    private var screenshotsPage: some View {
        VStack(spacing: 0) {
            pageHeader(title: AppStoreConnectLocalization.string("Screenshots"), subtitle: AppStoreConnectLocalization.string("Validate and prepare screenshots for the selected localization"))

            HStack {
                Picker(AppStoreConnectLocalization.string("Display"), selection: $viewModel.selectedScreenshotDisplayType) {
                    ForEach(viewModel.screenshotDisplayTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .frame(width: 260)

                AppButton(AppStoreConnectLocalization.string("Add Screenshots"), systemImage: "plus", size: .small) {
                    importingScreenshots = true
                }
                .disabled(viewModel.selectedLocalizationID == nil)

                AppButton(AppStoreConnectLocalization.string("Ensure Screenshot Set"), systemImage: "folder.badge.plus", size: .small) {
                    Task { await viewModel.ensureScreenshotSet() }
                }
                .disabled(viewModel.selectedLocalizationID == nil)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            ScreenshotSetSummary(sets: viewModel.screenshotSets)

            List {
                ForEach(viewModel.pendingScreenshots) { screenshot in
                    PendingScreenshotRow(screenshot: screenshot) {
                        viewModel.removeScreenshot(screenshot)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var xcodeCloudPage: some View {
        VStack(spacing: 0) {
            pageHeader(
                title: AppStoreConnectLocalization.string("Xcode Cloud"),
                subtitle: viewModel.selectedApp.map { AppStoreConnectLocalization.string("Workflows and build runs for %@", $0.name) } ?? AppStoreConnectLocalization.string("Select an app first")
            )

            HStack(spacing: 10) {
                Picker(AppStoreConnectLocalization.string("Product"), selection: Binding(
                    get: { viewModel.selectedCiProduct?.id ?? "" },
                    set: { id in
                        if let product = viewModel.ciProducts.first(where: { $0.id == id }) {
                            viewModel.selectCiProduct(product)
                        }
                    }
                )) {
                    if viewModel.ciProducts.isEmpty {
                        Text(AppStoreConnectLocalization.string("No Products")).tag("")
                    } else {
                        ForEach(viewModel.ciProducts) { product in
                            Text(product.name).tag(product.id)
                        }
                    }
                }
                .frame(width: 280)

                AppButton(AppStoreConnectLocalization.string("Load Products"), systemImage: "square.and.arrow.down", size: .small) {
                    Task { await viewModel.loadCiProducts() }
                }
                .disabled(!viewModel.credentials.isComplete)

                AppButton(AppStoreConnectLocalization.string("Build Runs"), systemImage: "arrow.clockwise", size: .small) {
                    Task { await viewModel.loadCiBuildRuns() }
                }
                .disabled(viewModel.selectedCiWorkflow == nil)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if viewModel.ciProducts.isEmpty {
                AppEmptyState(
                    icon: "cloud",
                    title: AppStoreConnectLocalization.string("No Xcode Cloud Products Loaded"),
                    description: AppStoreConnectLocalization.string("Load products from App Store Connect to inspect workflows and start builds.")
                )
            } else {
                HStack(spacing: 0) {
                    xcodeCloudWorkflowList
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)

                    Divider()

                    xcodeCloudDetail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var xcodeCloudWorkflowList: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppStoreConnectLocalization.string("Workflows"))
                        .font(.headline)
                    Text(viewModel.selectedCiProduct?.bundleID ?? "-")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            List(selection: Binding(
                get: { viewModel.selectedCiWorkflow?.id },
                set: { id in
                    if let id, let workflow = viewModel.ciWorkflows.first(where: { $0.id == id }) {
                        viewModel.selectCiWorkflow(workflow)
                    }
                }
            )) {
                ForEach(viewModel.ciWorkflows) { workflow in
                    CiWorkflowRow(workflow: workflow)
                        .tag(workflow.id)
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private var xcodeCloudDetail: some View {
        if let workflow = viewModel.selectedCiWorkflowDetail ?? viewModel.selectedCiWorkflow {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workflow.name)
                                        .font(.title3.weight(.semibold))
                                    Text(workflow.description.isEmpty ? workflow.containerFilePath : workflow.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                CiStatusBadge(
                                    text: workflow.isEnabled ? AppStoreConnectLocalization.string("Enabled") : AppStoreConnectLocalization.string("Disabled"),
                                    color: workflow.isEnabled ? .green : .secondary
                                )
                            }

                            HStack(spacing: 8) {
                                AppButton(
                                    workflow.isEnabled ? AppStoreConnectLocalization.string("Disable Workflow") : AppStoreConnectLocalization.string("Enable Workflow"),
                                    systemImage: workflow.isEnabled ? "pause.fill" : "play.fill",
                                    size: .small
                                ) {
                                    Task { await viewModel.toggleSelectedCiWorkflowEnabled() }
                                }
                                .disabled(viewModel.selectedCiWorkflow == nil)

                                AppButton(AppStoreConnectLocalization.string("Copy Config"), systemImage: "doc.on.doc", size: .small) {
                                    viewModel.copySelectedCiWorkflowConfiguration()
                                }

                                Spacer()
                            }

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)], alignment: .leading, spacing: 10) {
                                CiInfoCell(title: AppStoreConnectLocalization.string("Platform"), value: workflow.platformType)
                                CiInfoCell(title: AppStoreConnectLocalization.string("Clean Build"), value: workflow.clean ? AppStoreConnectLocalization.string("Yes") : AppStoreConnectLocalization.string("No"))
                                CiInfoCell(title: AppStoreConnectLocalization.string("Container"), value: workflow.containerFilePath.isEmpty ? "-" : workflow.containerFilePath)
                                CiInfoCell(title: AppStoreConnectLocalization.string("Created"), value: workflow.createdDate.map(Self.dateTimeFormatter.string(from:)) ?? "-")
                            }
                        }
                    }

                    AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppStoreConnectLocalization.string("Start Build"))
                                .font(.headline)

                            HStack {
                                GlassTextField(
                                    title: AppStoreConnectLocalization.string("Branch or Tag"),
                                    text: $viewModel.ciSourceBranchOrTag
                                )

                                AppButton(AppStoreConnectLocalization.string("Start Build"), systemImage: "play.fill", style: .primary) {
                                    Task { await viewModel.startCiBuildRun() }
                                }
                                .disabled(!workflow.isEnabled || viewModel.selectedCiWorkflow == nil)
                            }
                        }
                    }

                    AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(AppStoreConnectLocalization.string("Workflow Config"))
                                    .font(.headline)
                                Spacer()
                                AppButton(AppStoreConnectLocalization.string("Copy"), systemImage: "doc.on.doc", size: .small) {
                                    viewModel.copySelectedCiWorkflowConfiguration()
                                }
                            }

                            Text(viewModel.ciWorkflowExportJSON.isEmpty ? "-" : viewModel.ciWorkflowExportJSON)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(AppStoreConnectLocalization.string("Recent Build Runs"))
                                .font(.headline)
                            Spacer()
                            AppButton(AppStoreConnectLocalization.string("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                                Task { await viewModel.loadCiBuildRuns() }
                            }
                            .disabled(viewModel.selectedCiWorkflow == nil)
                        }

                        if viewModel.ciBuildRuns.isEmpty {
                            AppEmptyState(
                                icon: "hammer",
                                title: AppStoreConnectLocalization.string("No Build Runs"),
                                description: AppStoreConnectLocalization.string("Refresh build runs or start a build for this workflow.")
                            )
                            .frame(minHeight: 180)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(viewModel.ciBuildRuns) { buildRun in
                                    CiBuildRunRow(buildRun: buildRun)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        } else {
            AppEmptyState(
                icon: "point.3.connected.trianglepath.dotted",
                title: AppStoreConnectLocalization.string("No Workflow Selected"),
                description: AppStoreConnectLocalization.string("Choose a workflow to inspect details and recent build runs.")
            )
        }
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

public struct AppStoreConnectToolbarAppPicker: View {
    @ObservedObject private var viewModel: AppStoreConnectViewModel
    @State private var showingAppPicker = false

    public init() {
        self.viewModel = .shared
    }

    public var body: some View {
        Button {
            showingAppPicker.toggle()
        } label: {
            HStack(spacing: 8) {
                AppStoreIconView(url: viewModel.selectedApp?.iconURL, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.selectedApp?.name ?? AppStoreConnectLocalization.string("Select App"))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(viewModel.selectedApp?.bundleID ?? AppStoreConnectLocalization.string("Choose an App Store Connect app"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 320)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.credentials.isComplete)
        .popover(isPresented: $showingAppPicker, arrowEdge: .bottom) {
            AppStoreAppPicker(viewModel: viewModel) {
                showingAppPicker = false
            }
        }
    }
}

private struct AppStoreConnectErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            AppErrorBanner(message: LocalizedStringKey(message))

            AppButton(AppStoreConnectLocalization.string("Copy"), systemImage: "doc.on.doc", size: .small) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }
        }
    }
}

private struct AppStoreAppRow: View {
    let app: AppStoreApp

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                AppStoreIconView(url: app.iconURL)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.body.weight(.medium))
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(app.sku)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(app.primaryLocale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
                Text(app.platform)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }
}

private struct AppStoreAppPicker: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            pickerToolbar
            pickerContent
        }
        .padding(12)
        .frame(width: 380)
        .task {
            if viewModel.credentials.isComplete && viewModel.apps.isEmpty {
                await viewModel.loadApps()
            }
        }
    }

    private var pickerToolbar: some View {
        HStack {
            AppSearchBar(text: $viewModel.searchText, placeholder: LocalizedStringKey(AppStoreConnectLocalization.string("Search apps")))

            AppButton(AppStoreConnectLocalization.string("Reload"), systemImage: "arrow.clockwise", size: .small) {
                Task { await viewModel.loadApps() }
            }
            .disabled(viewModel.isBusy)
        }
    }

    @ViewBuilder
    private var pickerContent: some View {
        if viewModel.filteredApps.isEmpty {
            AppEmptyState(
                icon: "square.grid.2x2",
                title: AppStoreConnectLocalization.string("No Apps"),
                description: AppStoreConnectLocalization.string("Load apps from App Store Connect or adjust your search.")
            )
            .frame(height: 180)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.filteredApps) { app in
                        appRow(app)
                    }
                }
            }
            .frame(maxHeight: 360)
        }
    }

    private func appRow(_ app: AppStoreApp) -> some View {
        AppListRow(isSelected: viewModel.selectedApp?.id == app.id, action: {
            viewModel.selectApp(app, openVersions: true)
            onSelect()
        }) {
            HStack(spacing: 10) {
                AppStoreIconView(url: app.iconURL, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(app.primaryLocale)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.selectedApp?.id == app.id {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}

private struct AppStoreIconView: View {
    let url: URL?
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: min(8, size * 0.24), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: min(8, size * 0.24), style: .continuous)
                .stroke(Color.secondary.opacity(0.16))
        )
    }

    private var fallback: some View {
        Image(systemName: "app.dashed")
            .font(.system(size: size * 0.52, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.08))
    }
}

private struct AppStoreVersionRow: View {
    let version: AppStoreVersion

    var body: some View {
        AppListRow {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(version.versionString)
                        .font(.body.weight(.medium))
                    Text(version.appVersionState)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(version.platform)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(version.appStoreState)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
        }
    }
}

private struct MetadataEditor: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                field(AppStoreConnectLocalization.string("Promotional Text"), limit: 170, text: binding(\.promotionalText), axis: .vertical)
                field(AppStoreConnectLocalization.string("Description"), limit: 4000, text: binding(\.description), axis: .vertical, height: 160)
                field(AppStoreConnectLocalization.string("Keywords"), limit: 100, text: binding(\.keywords))
                field(AppStoreConnectLocalization.string("What's New"), limit: 4000, text: binding(\.whatsNew), axis: .vertical, height: 120)
                field(AppStoreConnectLocalization.string("Support URL"), limit: 255, text: binding(\.supportURL))
                field(AppStoreConnectLocalization.string("Marketing URL"), limit: 255, text: binding(\.marketingURL))
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppStoreVersionLocalization, String>) -> Binding<String> {
        Binding(
            get: { viewModel.editedLocalization?[keyPath: keyPath] ?? "" },
            set: { newValue in
                viewModel.editedLocalization?[keyPath: keyPath] = newValue
                viewModel.markMetadataDirty()
            }
        )
    }

    private func field(
        _ title: String,
        limit: Int,
        text: Binding<String>,
        axis: Axis = .horizontal,
        height: CGFloat? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(text.wrappedValue.count)/\(limit)")
                    .font(.caption2)
                    .foregroundStyle(text.wrappedValue.count > limit ? .red : .secondary)
            }

            if axis == .vertical {
                TextEditor(text: text)
                    .font(.body)
                    .frame(minHeight: height ?? 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.22))
                    )
            } else {
                GlassTextField(title: title, text: text)
            }
        }
    }
}

private struct ScreenshotSetSummary: View {
    let sets: [ScreenshotSet]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                if sets.isEmpty {
                    Text(AppStoreConnectLocalization.string("No screenshot sets loaded"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sets) { set in
                        Text(set.screenshotDisplayType)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

private struct PendingScreenshotRow: View {
    let screenshot: PendingScreenshot
    let onRemove: () -> Void

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                Image(systemName: "photo")
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(screenshot.fileName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text("\(screenshot.width) x \(screenshot.height) · \(screenshot.displayType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                status

                AppIconButton(systemImage: "trash", tint: .red, action: onRemove)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch screenshot.status {
        case .ready:
            Label(AppStoreConnectLocalization.string("Ready"), systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .invalid(let message):
            Label(message, systemImage: "xmark.octagon")
                .foregroundStyle(.red)
        case .uploading:
            Label(AppStoreConnectLocalization.string("Uploading"), systemImage: "arrow.up.circle")
                .foregroundStyle(.secondary)
        case .uploaded:
            Label(AppStoreConnectLocalization.string("Uploaded"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}

private struct CiWorkflowRow: View {
    let workflow: CiWorkflow

    var body: some View {
        AppListRow {
            HStack(spacing: 10) {
                Image(systemName: workflow.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                    .font(.title3)
                    .foregroundStyle(workflow.isEnabled ? .green : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(workflow.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(workflow.containerFilePath.isEmpty ? workflow.platformType : workflow.containerFilePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }
}

private struct CiInfoCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .lineLimit(2)
        }
    }
}

private struct CiStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct CiBuildRunRow: View {
    let buildRun: CiBuildRun

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text(buildRun.number.map { AppStoreConnectLocalization.string("Build #%d", $0) } ?? buildRun.id)
                        .font(.body.weight(.medium))
                    Text(timeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CiStatusBadge(text: statusText, color: statusColor)
            }
        }
    }

    private var statusText: String {
        buildRun.completionStatus ?? buildRun.executionProgress
    }

    private var statusIcon: String {
        switch statusText {
        case "SUCCEEDED":
            return "checkmark.circle.fill"
        case "FAILED", "ERRORED":
            return "xmark.octagon.fill"
        case "CANCELED":
            return "stop.circle.fill"
        case "RUNNING":
            return "play.circle.fill"
        default:
            return "clock"
        }
    }

    private var statusColor: Color {
        switch statusText {
        case "SUCCEEDED":
            return .green
        case "FAILED", "ERRORED":
            return .red
        case "CANCELED":
            return .orange
        case "RUNNING":
            return .blue
        default:
            return .secondary
        }
    }

    private var timeSummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let created = buildRun.createdDate.map(formatter.string(from:)) ?? "-"
        let finished = buildRun.finishedDate.map(formatter.string(from:))
        if let finished {
            return AppStoreConnectLocalization.string("Created %@ · Finished %@", created, finished)
        }
        return AppStoreConnectLocalization.string("Created %@", created)
    }
}

private struct AppStoreConnectAccountGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStoreConnectLocalization.string("App Store Connect API Key Setup"))
                        .font(.title2.weight(.semibold))
                    Text(AppStoreConnectLocalization.string("Create one user-level API key, then paste the values into the Account page."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                AppIconButton(systemImage: "xmark") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    guideStep(
                        number: "1",
                        title: AppStoreConnectLocalization.string("Open Users and Access"),
                        body: AppStoreConnectLocalization.string("Sign in to App Store Connect with an account that can manage API keys, then open Users and Access.")
                    )

                    guideStep(
                        number: "2",
                        title: AppStoreConnectLocalization.string("Create an API key"),
                        body: AppStoreConnectLocalization.string("Go to the Keys tab, create a new key, choose the minimum role needed for app metadata and screenshot management, then save it.")
                    )

                    guideStep(
                        number: "3",
                        title: AppStoreConnectLocalization.string("Copy Issuer ID and Key ID"),
                        body: AppStoreConnectLocalization.string("Issuer ID is shown on the Keys page. Key ID is shown next to the key you created. Paste both into Lumi.")
                    )

                    guideStep(
                        number: "4",
                        title: AppStoreConnectLocalization.string("Download the .p8 private key"),
                        body: AppStoreConnectLocalization.string("Download the private key immediately. Apple only lets you download it once. Open the .p8 file and paste the full contents into the Private Key field.")
                    )

                    guideStep(
                        number: "5",
                        title: AppStoreConnectLocalization.string("Save and test"),
                        body: AppStoreConnectLocalization.string("Click Save Credentials, then Test Connection. Lumi stores the values in Keychain and uses them to generate short-lived JWT tokens.")
                    )

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppStoreConnectLocalization.string("Security notes"))
                            .font(.headline)
                        Label(AppStoreConnectLocalization.string("Use the least privileged App Store Connect role that still allows the workflow you need."), systemImage: "lock")
                        Label(AppStoreConnectLocalization.string("Do not commit the .p8 key to source control or paste it into project files."), systemImage: "exclamationmark.triangle")
                        Label(AppStoreConnectLocalization.string("If a key is exposed, revoke it in App Store Connect and create a replacement."), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .font(.callout)

                    AppButton(AppStoreConnectLocalization.string("Open App Store Connect API Keys"), systemImage: "safari", style: .secondary) {
                        if let url = URL(string: "https://appstoreconnect.apple.com/access/integrations/api") {
                            openURL(url)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
        }
        .frame(width: 640, height: 620)
    }

    private func guideStep(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
