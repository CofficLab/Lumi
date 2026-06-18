import HTMLPreviewKit
import LumiUI
import SwiftUI
import WebKit

struct CoverArtPage: View {
    @ObservedObject var viewModel: VM
    @State private var showingCreateSheet = false
    @State private var previewWebView: WKWebView?
    @State private var fileMonitor: DispatchSourceFileSystemObject?

    var body: some View {
        VStack(spacing: 12) {
            header

            if viewModel.selectedApp == nil {
                AppEmptyState(
                    icon: "square.grid.2x2",
                    title: AppStoreConnectLocalization.string("No App Selected"),
                    description: AppStoreConnectLocalization.string("Select an app from the Apps page or toolbar picker.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.hasOpenProject {
                AppEmptyState(
                    icon: "folder",
                    title: AppStoreConnectLocalization.string("No Project Open"),
                    description: AppStoreConnectLocalization.string("Open a project first so cover art HTML can be stored under .lumi.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingCreateSheet) {
            CoverArtCreateSheet(viewModel: viewModel, isPresented: $showingCreateSheet)
        }
        .onAppear {
            viewModel.reloadCoverArtList()
            startWatchingSelectedFile()
        }
        .onDisappear {
            stopWatchingSelectedFile()
        }
        .onChange(of: viewModel.selectedCoverArtSlug) { _, _ in
            startWatchingSelectedFile()
        }
        .onChange(of: viewModel.page) { _, page in
            if page == .coverArt {
                viewModel.reloadCoverArtList()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("lumi.currentProjectPathDidChange"))) { _ in
            viewModel.reloadCoverArtList()
        }
    }

    private var header: some View {
        AppToolbarContainer(padding: appStoreToolbarPadding) {
            HStack(spacing: 16) {
                Spacer()

                if viewModel.hasOpenProject, viewModel.selectedApp != nil {
                    AppButton(AppStoreConnectLocalization.string("New Cover Art"), systemImage: "plus", size: .small) {
                        showingCreateSheet = true
                    }

                    AppButton(AppStoreConnectLocalization.string("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                        viewModel.reloadCoverArtList()
                    }

                    if viewModel.selectedCoverArtManifest != nil {
                        AppButton(AppStoreConnectLocalization.string("Add to Chat"), systemImage: "bubble.left.and.text.bubble.right", size: .small) {
                            postCoverArtToChat()
                        }

                        AppButton(AppStoreConnectLocalization.string("Export PNG"), systemImage: "square.and.arrow.down", style: .primary, size: .small) {
                            Task { await viewModel.exportSelectedCoverArtPNG() }
                        }
                        .disabled(viewModel.selectedCoverArtPreviewSize == nil)
                    }
                }
            }
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            CoverArtListPanel(viewModel: viewModel)
                .frame(width: 240)

            VStack(alignment: .leading, spacing: 8) {
                if viewModel.selectedCoverArtManifest != nil, !viewModel.coverArtPreviewSizes.isEmpty {
                    CoverArtSizeStrip(
                        sizes: viewModel.coverArtPreviewSizes,
                        selectedDisplayType: viewModel.coverArtPreviewDisplayType,
                        onSelect: { viewModel.selectCoverArtPreviewDisplayType($0) }
                    )
                }

                if viewModel.selectedCoverArtManifest == nil {
                    InlineEmptyState(
                        icon: "photo.artframe",
                        title: AppStoreConnectLocalization.string("No Cover Art Yet"),
                        description: AppStoreConnectLocalization.string("Create a cover art document, then refine its HTML with the agent."),
                        actionTitle: AppStoreConnectLocalization.string("New Cover Art"),
                        action: { showingCreateSheet = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let previewSize = viewModel.selectedCoverArtPreviewSize {
                    HTMLPreviewView(
                        htmlText: viewModel.coverArtHTML,
                        fileURL: viewModel.coverArtFileURL,
                        contentSize: CGSize(width: previewSize.width, height: previewSize.height),
                        onWebViewResolved: { webView in
                            previewWebView = webView
                        }
                    )
                    .id("\(viewModel.coverArtReloadToken.uuidString)-\(previewSize.displayType)")
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.15))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.trailing)
        }
        .padding(.bottom, 12)
    }

    private func postCoverArtToChat() {
        guard let app = viewModel.selectedApp,
              let manifest = viewModel.selectedCoverArtManifest,
              let htmlPath = viewModel.coverArtFileURL?.path else { return }

        let previewDisplayTypes = manifest.previewSizes.map(\.displayType).joined(separator: ", ")

        AddToChat.post(
            entityType: "coverArtDocument",
            entityID: manifest.id,
            title: manifest.title,
            sourceView: "CoverArtPage",
            fields: [
                "appID": app.id,
                "slug": manifest.id,
                "deviceFamily": manifest.deviceFamily.rawValue,
                "previewDisplayTypes": previewDisplayTypes,
                "htmlPath": htmlPath,
                "projectPath": viewModel.currentProjectPath
            ],
            mode: .analyze
        )
    }

    private func startWatchingSelectedFile() {
        stopWatchingSelectedFile()
        guard let fileURL = viewModel.coverArtFileURL else { return }

        let fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.main
        )
        source.setEventHandler {
            viewModel.refreshSelectedCoverArtFromDisk()
        }
        source.setCancelHandler {
            close(fileDescriptor)
        }
        source.resume()
        fileMonitor = source
    }

    private func stopWatchingSelectedFile() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }
}

private struct CoverArtListPanel: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 10, showShadow: false) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.coverArtItems) { item in
                        Button {
                            viewModel.selectCoverArt(slug: item.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.callout.weight(viewModel.selectedCoverArtSlug == item.id ? .semibold : .regular))
                                    .lineLimit(1)
                                Text(item.deviceFamily.localizedTitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedCoverArtSlug == item.id
                                    ? Color.accentColor.opacity(0.14)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
        }
        .padding(.leading)
    }
}

private struct CoverArtCreateSheet: View {
    @ObservedObject var viewModel: VM
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var slug = ""
    @State private var deviceFamily = CoverArtDeviceFamily.iphone

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppStoreConnectLocalization.string("New Cover Art"))
                .font(.title3.weight(.semibold))

            GlassTextField(
                title: AppStoreConnectLocalization.string("Title"),
                text: $title
            )
            .onChange(of: title) { _, newValue in
                if slug.isEmpty {
                    slug = viewModel.suggestedCoverArtSlug(for: newValue)
                }
            }

            GlassTextField(
                title: AppStoreConnectLocalization.string("Slug"),
                text: $slug
            )

            Picker(AppStoreConnectLocalization.string("Device Family"), selection: $deviceFamily) {
                ForEach(viewModel.coverArtDeviceFamilies) { family in
                    Text(family.localizedTitle).tag(family)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                AppButton(AppStoreConnectLocalization.string("Cancel"), style: .secondary) {
                    isPresented = false
                }
                AppButton(AppStoreConnectLocalization.string("Create"), systemImage: "plus", style: .primary) {
                    let resolvedSlug = slug.isEmpty ? viewModel.suggestedCoverArtSlug(for: title) : slug
                    viewModel.createCoverArt(
                        deviceFamily: deviceFamily,
                        title: title,
                        slug: resolvedSlug
                    )
                    isPresented = false
                }
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            slug = viewModel.suggestedCoverArtSlug(for: title)
        }
    }
}
