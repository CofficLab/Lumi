import LumiUI
import SwiftUI
import LumiLoggingKit
struct DockerImagesView: View, SuperLog {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject private var viewModel: DockerManagerViewModel
    @State private var showPullSheet = false
    @State private var pullImageName = ""

    // Tagging
    @State private var showTagSheet = false
    @State private var newTag = ""
    @State private var imageToTag: DockerImage?

    // Import/Export
    @State private var showFileImporter = false
    @State private var showFileExporter = false
    @State private var imageToExport: DockerImage?

    init(viewModel: DockerManagerViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                AppErrorBanner(
                    message: LocalizedStringKey(errorMessage),
                    retryTitle: LocalizedStringKey(pluginLocalization.string("Dismiss"))
                ) {
                    viewModel.errorMessage = nil
                }
                .padding(8)
                GlassDivider()
            }

            HSplitView {
                // Sidebar List
                VStack(spacing: 0) {
                    // Toolbar
                    HStack {
                        AppSearchBar(
                            text: $viewModel.searchText,
                            placeholder: LocalizedStringKey(pluginLocalization.string("Search images..."))
                        )

                        Menu {
                            Picker(pluginLocalization.string("Sort"), selection: $viewModel.sortOption) {
                                Text(pluginLocalization.string("Created")).tag(DockerManagerViewModel.SortOption.created)
                                Text(pluginLocalization.string("Name")).tag(DockerManagerViewModel.SortOption.name)
                                Text(pluginLocalization.string("Size")).tag(DockerManagerViewModel.SortOption.size)
                            }
                            Toggle(pluginLocalization.string("Descending"), isOn: $viewModel.sortDescending)
                        } label: {
                            GlassRow {
                                Label(pluginLocalization.string("Sort"), systemImage: "arrow.up.arrow.down")
                                    .foregroundColor(theme.textPrimary)
                            }
                            .frame(width: 90)
                        }

                        AppIconButton(
                            systemImage: "arrow.clockwise",
                            label: pluginLocalization.string("Refresh"),
                            size: .regular
                        ) {
                            Task { await viewModel.refreshImages() }
                        }
                    }
                    .padding(8)
                    .background(Material.regularMaterial)

                    GlassDivider()

                    List(viewModel.filteredImages, selection: Binding(
                        get: { viewModel.selectedImage },
                        set: { newSelection in
                            if let img = newSelection {
                                Task { await viewModel.selectImage(img) }
                            } else {
                                viewModel.selectedImage = nil
                            }
                        }
                    )) { image in
                        DockerImageRow(image: image)
                            .tag(image)
                            .contextMenu {
                                Button(pluginLocalization.string("Tag...")) {
                                    imageToTag = image
                                    newTag = image.repository + ":"
                                    showTagSheet = true
                                }
                                Button(pluginLocalization.string("Export...")) {
                                    imageToExport = image
                                    showFileExporter = true
                                }
                                Button(pluginLocalization.string("Scan")) {
                                    Task { await viewModel.scanImage(image) }
                                }
                                Divider()
                                Button(pluginLocalization.string("Delete"), role: .destructive) {
                                    Task { await viewModel.deleteImage(image) }
                                }
                            }
                    }
                    .listStyle(.inset)

                    GlassDivider()

                    // Footer
                    HStack {
                        Text("\(viewModel.filteredImages.count) images")
                            .font(.appMicro)
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        AppButton(pluginLocalization.string("Import"), style: .secondary, size: .small) {
                            showFileImporter = true
                        }
                        AppButton(pluginLocalization.string("Pull"), style: .primary, size: .small) {
                            showPullSheet = true
                        }
                    }
                    .padding(8)
                    .background(Material.regularMaterial)
                }
                .frame(minWidth: 250, maxWidth: 400)

                // Detail View
                if let selected = viewModel.selectedImage {
                    DockerImageDetailView(image: selected, detail: viewModel.selectedImageDetail, history: viewModel.selectedImageHistory, viewModel: viewModel)
                } else {
                    AppEmptyState(
                        icon: "cube.box",
                        title: LocalizedStringKey(pluginLocalization.string("Select an image to view details"))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Material.regularMaterial)
                }
            }
        }
        .sheet(isPresented: $showPullSheet) {
            VStack(spacing: 20) {
                Text(pluginLocalization.string("Pull New Image"))
                    .font(.appTitle)
                    .foregroundColor(theme.textPrimary)
                GlassTextField(
                    title: pluginLocalization.string("Image"),
                    text: $pullImageName,
                    placeholder: "nginx:latest"
                )
                .frame(width: 320)

                if viewModel.isLoading {
                    ProgressView("Pulling...")
                }

                HStack {
                    AppButton(pluginLocalization.string("Cancel"), style: .ghost) { showPullSheet = false }
                    AppButton(pluginLocalization.string("Pull"), style: .primary) {
                        Task {
                            if await viewModel.pullImage(pullImageName) {
                                showPullSheet = false
                                pullImageName = ""
                            }
                        }
                    }
                    .disabled(!DockerImageReferenceValidator.isValidReference(pullImageName) || viewModel.isLoading)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showTagSheet) {
            VStack(spacing: 20) {
                Text(pluginLocalization.string("Tag Image"))
                    .font(.appTitle)
                    .foregroundColor(theme.textPrimary)
                if let img = imageToTag {
                    Text(pluginLocalization.string("Source:") + " \(img.name)")
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                }
                GlassTextField(
                    title: pluginLocalization.string("New Tag"),
                    text: $newTag,
                    placeholder: "myrepo:v1"
                )
                .frame(width: 320)

                HStack {
                    AppButton(pluginLocalization.string("Cancel"), style: .ghost) { showTagSheet = false }
                    AppButton(pluginLocalization.string("Confirm"), style: .primary) {
                        if let img = imageToTag {
                            Task {
                                if await viewModel.tagImage(img, newTag: newTag) {
                                    showTagSheet = false
                                }
                            }
                        }
                    }
                    .disabled(!DockerImageReferenceValidator.isValidReference(newTag) || viewModel.isLoading)
                }
            }
            .padding()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data]) { result in
            switch result {
            case let .success(url):
                Task { await viewModel.loadImage(from: url) }
            case let .failure(error):
                if DockerManagerPlugin.verbose {
                    DockerManagerPlugin.logger.error("\(Self.t)Import failed: \(error.localizedDescription)")
                }
                viewModel.reportFilePanelError(pluginLocalization.string("Import failed"), error: error)
            }
        }
        .fileExporter(isPresented: $showFileExporter, document: DockerImageDocument(image: imageToExport), contentType: .data, defaultFilename: imageToExport?.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") ?? "image") { result in
            switch result {
            case let .success(url):
                if let img = imageToExport {
                    Task { await viewModel.exportImage(img, to: url) }
                }
            case let .failure(error):
                if DockerManagerPlugin.verbose {
                    DockerManagerPlugin.logger.error("\(Self.t)Export failed: \(error.localizedDescription)")
                }
                viewModel.reportFilePanelError(pluginLocalization.string("Export failed"), error: error)
            }
        }
        .onAppear {
            Task { await viewModel.refreshImages() }
        }
        .navigationTitle(DockerManagerPlugin().name)
    }
}

import UniformTypeIdentifiers

struct DockerImageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    var image: DockerImage?

    init(image: DockerImage? = nil) {
        self.image = image
    }

    init(configuration: ReadConfiguration) throws {
        // Not used for export
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: Data()) // Actual content is written by docker save command directly to file path, this is just a placeholder to trigger exporter
    }
}

struct DockerImageRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let image: DockerImage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cube")
                .foregroundColor(theme.info)
            VStack(alignment: .leading, spacing: 2) {
                Text(image.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                Text(image.shortID)
                    .font(.appMicro)
                    .fontDesign(.monospaced)
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                AppTag(image.size)
                AppTag(image.createdSince)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DockerImageDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let image: DockerImage
    let detail: DockerInspect?
    let history: [DockerImageHistory]
    @ObservedObject var viewModel: DockerManagerViewModel
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                AppCard(style: .subtle, cornerRadius: 8) {
                    HStack {
                    VStack(alignment: .leading) {
                        Text(image.repository)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textPrimary)
                        HStack {
                            AppTag(image.tag, style: .accent)
                            Text(image.imageID)
                                .font(.monospaced(.caption)())
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    Spacer()

                    AppButton(pluginLocalization.string("Scan"), style: .secondary, fillsWidth: true, action: { Task { await viewModel.scanImage(image) } })

                    AppButton(pluginLocalization.string("Delete"), style: .destructive, fillsWidth: true, action: { showDeleteAlert = true })
                }
                }

                // Scan Result
                if let scanResult = viewModel.scanResult {
                    AppCard(style: .subtle, cornerRadius: 8) {
                        VStack(alignment: .leading, spacing: 8) {
                        Text(pluginLocalization.string("Security Scan"))
                            .font(.appBody)
                            .foregroundColor(theme.textPrimary)

                        ScrollView([.horizontal, .vertical]) {
                            Text(scanResult)
                                .font(.monospaced(.caption)())
                                .foregroundColor(theme.textPrimary)
                                .padding()
                        }
                        .frame(maxHeight: 200)
                        .background(Material.regularMaterial)
                        .cornerRadius(4)
                    }
                    }
                }

                // Info Grid
                if let detail = detail {
                    AppCard(style: .subtle, cornerRadius: 8) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        InfoRow(title: pluginLocalization.string("Architecture"), value: detail.Architecture)
                        InfoRow(title: "OS", value: detail.Os)
                        InfoRow(title: pluginLocalization.string("Author"), value: detail.Author ?? "-")
                        InfoRow(title: "Virtual Size", value: ByteCountFormatter.string(fromByteCount: detail.VirtualSize ?? 0, countStyle: .file))
                    }
                    }

                    // Config
                    if let config = detail.Config {
                        AppCard(style: .subtle, cornerRadius: 8) {
                            VStack(alignment: .leading, spacing: 8) {
                            Text(pluginLocalization.string("Configuration"))
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)

                            if let cmds = config.Cmd {
                                Text(pluginLocalization.string("CMD: ") + cmds.joined(separator: " "))
                                    .font(.monospaced(.caption)())
                            }

                            if let envs = config.Env {
                                Text(pluginLocalization.string("ENV:"))
                                    .font(.appMicro)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textSecondary)
                                ForEach(envs.prefix(5), id: \.self) { env in
                                    Text(env)
                                        .font(.monospaced(.caption)())
                                        .foregroundColor(theme.textSecondary)
                                }
                                if envs.count > 5 {
                                    Text("... (+ \(envs.count - 5)) " + pluginLocalization.string("more"))
                                        .font(.appMicro)
                                        .foregroundColor(theme.textTertiary)
                                }
                            }
                        }
                        }
                    }
                }

                // History/Layers
                AppCard(style: .subtle, cornerRadius: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                    Text(pluginLocalization.string("History / Layers"))
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)

                    ForEach(history) { layer in
                        HStack(alignment: .top) {
                            Text(layer.id.prefix(8))
                                .font(.monospaced(.caption)())
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 60, alignment: .leading)

                            Text(layer.CreatedBy)
                                .font(.monospaced(.caption)())
                                .lineLimit(2)
                                .foregroundColor(theme.textPrimary)

                            Spacer()

                            Text(layer.Size)
                                .font(.appMicro)
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.vertical, 4)
                        GlassDivider()
                    }
                }
                }
            }
            .padding()
        }
        .background(Material.regularMaterial)
        .alert(pluginLocalization.string("Confirm Delete"), isPresented: $showDeleteAlert) {
            Button(pluginLocalization.string("Cancel"), role: .cancel) { }
            Button(pluginLocalization.string("Delete"), role: .destructive) {
                Task { await viewModel.deleteImage(image) }
            }
        } message: {
            Text("Are you sure you want to delete image \(image.name)? This action cannot be undone.")
        }
        .navigationTitle(DockerManagerPlugin().name)
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        GlassKeyValueRow(label: title, value: value)
    }
}
