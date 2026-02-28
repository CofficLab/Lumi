import SwiftUI

struct DockerImagesView: View {
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
        HSplitView {
            // Sidebar List
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    GlassTextField(
                        title: "搜索",
                        text: $viewModel.searchText,
                        placeholder: "Search images..."
                    )

                    Menu {
                        Picker("Sort", selection: $viewModel.sortOption) {
                            Text("Created").tag(DockerManagerViewModel.SortOption.created)
                            Text("Name").tag(DockerManagerViewModel.SortOption.name)
                            Text("Size").tag(DockerManagerViewModel.SortOption.size)
                        }
                        Toggle("Descending", isOn: $viewModel.sortDescending)
                    } label: {
                        GlassRow {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                        }
                        .frame(width: 90)
                    }

                    GlassButton(title: "Refresh", style: .secondary) {
                        Task { await viewModel.refreshImages() }
                    }
                }
                .padding(8)
                .background(DesignTokens.Material.glass)

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
                            Button("Tag...") {
                                imageToTag = image
                                newTag = image.Repository + ":"
                                showTagSheet = true
                            }
                            Button("Export...") {
                                imageToExport = image
                                showFileExporter = true
                            }
                            Button("Scan") {
                                Task { await viewModel.scanImage(image) }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                Task { await viewModel.deleteImage(image) }
                            }
                        }
                }
                .listStyle(.inset)

                GlassDivider()

                // Footer
                HStack {
                    Text("\(viewModel.filteredImages.count) images")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Spacer()
                    GlassButton(title: "Import", style: .secondary) {
                        showFileImporter = true
                    }
                    GlassButton(title: "Pull", style: .primary) {
                        showPullSheet = true
                    }
                }
                .padding(8)
                .background(DesignTokens.Material.glass)
            }
            .frame(minWidth: 250, maxWidth: 400)

            // Detail View
            if let selected = viewModel.selectedImage {
                DockerImageDetailView(image: selected, detail: viewModel.selectedImageDetail, history: viewModel.selectedImageHistory, viewModel: viewModel)
            } else {
                VStack {
                    Image(systemName: "cube.box")
                        .font(.system(size: 48))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text("Select an image to view details")
                        .font(.title2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.Material.glass)
            }
        }
        .sheet(isPresented: $showPullSheet) {
            VStack(spacing: 20) {
                Text("Pull New Image")
                    .font(DesignTokens.Typography.title2)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
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
                    GlassButton(title: "Cancel", style: .ghost) { showPullSheet = false }
                    GlassButton(title: "Pull", style: .primary) {
                        Task {
                            await viewModel.pullImage(pullImageName)
                            showPullSheet = false
                        }
                    }
                    .disabled(pullImageName.isEmpty || viewModel.isLoading)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showTagSheet) {
            VStack(spacing: 20) {
                Text("Tag Image")
                    .font(DesignTokens.Typography.title2)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                if let img = imageToTag {
                    Text("Source: \(img.name)")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                GlassTextField(
                    title: "New Tag",
                    text: $newTag,
                    placeholder: "myrepo:v1"
                )
                .frame(width: 320)

                HStack {
                    GlassButton(title: "Cancel", style: .ghost) { showTagSheet = false }
                    GlassButton(title: "Confirm", style: .primary) {
                        if let img = imageToTag {
                            Task {
                                await viewModel.tagImage(img, newTag: newTag)
                                showTagSheet = false
                            }
                        }
                    }
                    .disabled(newTag.isEmpty || viewModel.isLoading)
                }
            }
            .padding()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data]) { result in
            switch result {
            case let .success(url):
                Task { await viewModel.loadImage(from: url) }
            case let .failure(error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
        .fileExporter(isPresented: $showFileExporter, document: DockerImageDocument(image: imageToExport), contentType: .data, defaultFilename: imageToExport?.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") ?? "image") { result in
            switch result {
            case let .success(url):
                if let img = imageToExport {
                    Task { await viewModel.exportImage(img, to: url) }
                }
            case let .failure(error):
                print("Export failed: \(error.localizedDescription)")
            }
        }
        .onAppear {
            Task { await viewModel.refreshImages() }
        }
        .navigationTitle(DockerManagerPlugin.displayName)
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
    let image: DockerImage

    var body: some View {
        HStack {
            Image(systemName: "cube")
                .foregroundColor(DesignTokens.Color.semantic.info)
            VStack(alignment: .leading) {
                Text(image.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text(image.shortID)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(image.Size)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text(image.CreatedSince)
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DockerImageDetailView: View {
    let image: DockerImage
    let detail: DockerInspect?
    let history: [DockerImageHistory]
    @ObservedObject var viewModel: DockerManagerViewModel
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(image.Repository)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                        HStack {
                            Text(image.Tag)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignTokens.Color.semantic.info.opacity(0.1))
                                .cornerRadius(4)
                            Text(image.imageID)
                                .font(.monospaced(.caption)())
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    }
                    Spacer()

                    GlassButton(title: "Scan", style: .secondary) {
                        Task { await viewModel.scanImage(image) }
                    }

                    GlassButton(title: "Delete", style: .danger) {
                        showDeleteAlert = true
                    }
                }
                .padding()
                .background(DesignTokens.Material.glass)
                .cornerRadius(8)

                // Scan Result
                if let scanResult = viewModel.scanResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Security Scan")
                            .font(.headline)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                        ScrollView([.horizontal, .vertical]) {
                            Text(scanResult)
                                .font(.monospaced(.caption)())
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                .padding()
                        }
                        .frame(maxHeight: 200)
                        .background(DesignTokens.Material.glass)
                        .cornerRadius(4)
                    }
                    .padding()
                    .background(DesignTokens.Material.glass)
                    .cornerRadius(8)
                }

                // Info Grid
                if let detail = detail {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        InfoRow(title: "Architecture", value: detail.Architecture)
                        InfoRow(title: "OS", value: detail.Os)
                        InfoRow(title: "Author", value: detail.Author ?? "-")
                        InfoRow(title: "Virtual Size", value: ByteCountFormatter.string(fromByteCount: detail.VirtualSize ?? 0, countStyle: .file))
                    }
                    .padding()
                    .background(DesignTokens.Material.glass)
                    .cornerRadius(8)

                    // Config
                    if let config = detail.Config {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Configuration")
                                .font(.headline)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            if let cmds = config.Cmd {
                                Text("CMD: " + cmds.joined(separator: " "))
                                    .font(.monospaced(.caption)())
                            }

                            if let envs = config.Env {
                                Text("ENV:")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                ForEach(envs.prefix(5), id: \.self) { env in
                                    Text(env)
                                        .font(.monospaced(.caption)())
                                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                }
                                if envs.count > 5 {
                                    Text("... (+ \(envs.count - 5) more)")
                                        .font(.caption)
                                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                                }
                            }
                        }
                        .padding()
                        .background(DesignTokens.Material.glass)
                        .cornerRadius(8)
                    }
                }

                // History/Layers
                VStack(alignment: .leading, spacing: 8) {
                    Text("History / Layers")
                        .font(.headline)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    ForEach(history) { layer in
                        HStack(alignment: .top) {
                            Text(layer.id.prefix(8))
                                .font(.monospaced(.caption)())
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                .frame(width: 60, alignment: .leading)

                            Text(layer.CreatedBy)
                                .font(.monospaced(.caption)())
                                .lineLimit(2)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            Spacer()

                            Text(layer.Size)
                                .font(.caption)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                        .padding(.vertical, 4)
                        GlassDivider()
                    }
                }
                .padding()
                .background(DesignTokens.Material.glass)
                .cornerRadius(8)
            }
            .padding()
        }
        .background(DesignTokens.Material.glass)
        .alert("Confirm Delete", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteImage(image) }
            }
        } message: {
            Text("Are you sure you want to delete image \(image.name)? This action cannot be undone.")
        }
        .navigationTitle(DockerManagerPlugin.displayName)
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
        }
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DockerManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
