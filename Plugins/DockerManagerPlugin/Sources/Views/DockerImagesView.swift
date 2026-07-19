import LumiUI
import SwiftUI
import SuperLogKit

struct DockerImagesView: View, SuperLog {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel = DockerManagerViewModel()
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

    var body: some View {
        VStack(spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                AppErrorBanner(
                    message: LocalizedStringKey(errorMessage),
                    retryTitle: LocalizedStringKey(LumiPluginLocalization.string("Dismiss", bundle: .module))
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
                            placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search images...", bundle: .module))
                        )

                        Menu {
                            Picker("Sort", selection: $viewModel.sortOption) {
                                Text(LumiPluginLocalization.string("Created", bundle: .module)).tag(DockerManagerViewModel.SortOption.created)
                                Text(LumiPluginLocalization.string("Name", bundle: .module)).tag(DockerManagerViewModel.SortOption.name)
                                Text(LumiPluginLocalization.string("Size", bundle: .module)).tag(DockerManagerViewModel.SortOption.size)
                            }
                            Toggle("Descending", isOn: $viewModel.sortDescending)
                        } label: {
                            GlassRow {
                                Label(LumiPluginLocalization.string("Sort", bundle: .module), systemImage: "arrow.up.arrow.down")
                                    .foregroundColor(theme.textPrimary)
                            }
                            .frame(width: 90)
                        }

                        AppIconButton(
                            systemImage: "arrow.clockwise",
                            label: LumiPluginLocalization.string("Refresh", bundle: .module),
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
                                Button(LumiPluginLocalization.string("Tag...", bundle: .module)) {
                                    imageToTag = image
                                    newTag = image.repository + ":"
                                    showTagSheet = true
                                }
                                Button(LumiPluginLocalization.string("Export...", bundle: .module)) {
                                    imageToExport = image
                                    showFileExporter = true
                                }
                                Button(LumiPluginLocalization.string("Scan", bundle: .module)) {
                                    Task { await viewModel.scanImage(image) }
                                }
                                Divider()
                                Button(LumiPluginLocalization.string("Delete", bundle: .module), role: .destructive) {
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
                        AppButton(LumiPluginLocalization.string("Import", bundle: .module), style: .secondary, size: .small) {
                            showFileImporter = true
                        }
                        AppButton(LumiPluginLocalization.string("Pull", bundle: .module), style: .primary, size: .small) {
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
                        title: LocalizedStringKey(LumiPluginLocalization.string("Select an image to view details", bundle: .module))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Material.regularMaterial)
                }
            }
        }
        .sheet(isPresented: $showPullSheet) {
            VStack(spacing: 20) {
                Text(LumiPluginLocalization.string("Pull New Image", bundle: .module))
                    .font(.appTitle)
                    .foregroundColor(theme.textPrimary)
                GlassTextField(
                    title: "Image",
                    text: $pullImageName,
                    placeholder: "nginx:latest"
                )
                .frame(width: 320)

                if viewModel.isLoading {
                    ProgressView("Pulling...")
                }

                HStack {
                    AppButton(LumiPluginLocalization.string("Cancel", bundle: .module), style: .ghost) { showPullSheet = false }
                    AppButton(LumiPluginLocalization.string("Pull", bundle: .module), style: .primary) {
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
                Text(LumiPluginLocalization.string("Tag Image", bundle: .module))
                    .font(.appTitle)
                    .foregroundColor(theme.textPrimary)
                if let img = imageToTag {
                    Text(LumiPluginLocalization.string("Source:", bundle: .module) + " \(img.name)")
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                }
                GlassTextField(
                    title: "New Tag",
                    text: $newTag,
                    placeholder: "myrepo:v1"
                )
                .frame(width: 320)

                HStack {
                    AppButton(LumiPluginLocalization.string("Cancel", bundle: .module), style: .ghost) { showTagSheet = false }
                    AppButton(LumiPluginLocalization.string("Confirm", bundle: .module), style: .primary) {
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
                viewModel.reportFilePanelError(LumiPluginLocalization.string("Import failed", bundle: .module), error: error)
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
                viewModel.reportFilePanelError(LumiPluginLocalization.string("Export failed", bundle: .module), error: error)
            }
        }
        .onAppear {
            Task { await viewModel.refreshImages() }
        }
        .navigationTitle(DockerManagerPlugin.info.displayName)
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

                    AppButton("Scan", style: .secondary, fillsWidth: true, action: { Task { await viewModel.scanImage(image) } })

                    AppButton("Delete", style: .destructive, fillsWidth: true, action: { showDeleteAlert = true })
                }
                }

                // Scan Result
                if let scanResult = viewModel.scanResult {
                    AppCard(style: .subtle, cornerRadius: 8) {
                        VStack(alignment: .leading, spacing: 8) {
                        Text(LumiPluginLocalization.string("Security Scan", bundle: .module))
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
                        InfoRow(title: "Architecture", value: detail.Architecture)
                        InfoRow(title: "OS", value: detail.Os)
                        InfoRow(title: "Author", value: detail.Author ?? "-")
                        InfoRow(title: "Virtual Size", value: ByteCountFormatter.string(fromByteCount: detail.VirtualSize ?? 0, countStyle: .file))
                    }
                    }

                    // Config
                    if let config = detail.Config {
                        AppCard(style: .subtle, cornerRadius: 8) {
                            VStack(alignment: .leading, spacing: 8) {
                            Text(LumiPluginLocalization.string("Configuration", bundle: .module))
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)

                            if let cmds = config.Cmd {
                                Text("CMD: " + cmds.joined(separator: " "))
                                    .font(.monospaced(.caption)())
                            }

                            if let envs = config.Env {
                                Text(LumiPluginLocalization.string("ENV:", bundle: .module))
                                    .font(.appMicro)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textSecondary)
                                ForEach(envs.prefix(5), id: \.self) { env in
                                    Text(env)
                                        .font(.monospaced(.caption)())
                                        .foregroundColor(theme.textSecondary)
                                }
                                if envs.count > 5 {
                                    Text("... (+ \(envs.count - 5)) " + LumiPluginLocalization.string("more", bundle: .module))
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
                    Text(LumiPluginLocalization.string("History / Layers", bundle: .module))
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
        .alert(LumiPluginLocalization.string("Confirm Delete", bundle: .module), isPresented: $showDeleteAlert) {
            Button(LumiPluginLocalization.string("Cancel", bundle: .module), role: .cancel) { }
            Button(LumiPluginLocalization.string("Delete", bundle: .module), role: .destructive) {
                Task { await viewModel.deleteImage(image) }
            }
        } message: {
            Text("Are you sure you want to delete image \(image.name)? This action cannot be undone.")
        }
        .navigationTitle(DockerManagerPlugin.info.displayName)
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        GlassKeyValueRow(label: title, value: value)
    }
}
