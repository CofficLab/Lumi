import SwiftUI
import DockerKit

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
                            Text(String(localized: "Created", table: "DockerManager")).tag(DockerManagerViewModel.SortOption.created)
                            Text(String(localized: "Name", table: "DockerManager")).tag(DockerManagerViewModel.SortOption.name)
                            Text(String(localized: "Size", table: "DockerManager")).tag(DockerManagerViewModel.SortOption.size)
                        }
                        Toggle("Descending", isOn: $viewModel.sortDescending)
                    } label: {
                        GlassRow {
                            Label(String(localized: "Sort", table: "DockerManager"), systemImage: "arrow.up.arrow.down")
                                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        }
                        .frame(width: 90)
                    }

                    GlassButton(title: "Refresh", style: .secondary) {
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
                            Button(String(localized: "Tag...", table: "DockerManager")) {
                                imageToTag = image
                                newTag = image.repository + ":"
                                showTagSheet = true
                            }
                            Button(String(localized: "Export...", table: "DockerManager")) {
                                imageToExport = image
                                showFileExporter = true
                            }
                            Button(String(localized: "Scan", table: "DockerManager")) {
                                Task { await viewModel.scanImage(image) }
                            }
                            Divider()
                            Button(String(localized: "Delete", table: "DockerManager"), role: .destructive) {
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
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    Spacer()
                    GlassButton(title: "Import", style: .secondary) {
                        showFileImporter = true
                    }
                    GlassButton(title: "Pull", style: .primary) {
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
                VStack {
                    Image(systemName: "cube.box")
                        .font(.system(size: 48))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    Text(String(localized: "Select an image to view details", table: "DockerManager"))
                        .font(.title2)
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Material.regularMaterial)
            }
        }
        .sheet(isPresented: $showPullSheet) {
            VStack(spacing: 20) {
                Text(String(localized: "Pull New Image", table: "DockerManager"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
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
                Text(String(localized: "Tag Image", table: "DockerManager"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                if let img = imageToTag {
                    Text(String(localized: "Source:", table: "DockerManager") + " \(img.name)")
                        .font(.caption)
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
                DockerManagerPlugin.logger.error("\(DockerManagerPlugin.t)Import failed: \(error.localizedDescription)")
            }
        }
        .fileExporter(isPresented: $showFileExporter, document: DockerImageDocument(image: imageToExport), contentType: .data, defaultFilename: imageToExport?.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") ?? "image") { result in
            switch result {
            case let .success(url):
                if let img = imageToExport {
                    Task { await viewModel.exportImage(img, to: url) }
                }
            case let .failure(error):
                DockerManagerPlugin.logger.error("\(DockerManagerPlugin.t)Export failed: \(error.localizedDescription)")
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
                .foregroundColor(Color(hex: "0A84FF"))
            VStack(alignment: .leading) {
                Text(image.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                Text(image.shortID)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(image.size)
                    .font(.caption)
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                Text(image.createdSince)
                    .font(.caption2)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
                        Text(image.repository)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        HStack {
                            Text(image.tag)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "0A84FF").opacity(0.1))
                                .cornerRadius(4)
                            Text(image.imageID)
                                .font(.monospaced(.caption)())
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
                .background(Material.regularMaterial)
                .cornerRadius(8)

                // Scan Result
                if let scanResult = viewModel.scanResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Security Scan", table: "DockerManager"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                        ScrollView([.horizontal, .vertical]) {
                            Text(scanResult)
                                .font(.monospaced(.caption)())
                                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                                .padding()
                        }
                        .frame(maxHeight: 200)
                        .background(Material.regularMaterial)
                        .cornerRadius(4)
                    }
                    .padding()
                    .background(Material.regularMaterial)
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
                    .background(Material.regularMaterial)
                    .cornerRadius(8)

                    // Config
                    if let config = detail.Config {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "Configuration", table: "DockerManager"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                            if let cmds = config.Cmd {
                                Text("CMD: " + cmds.joined(separator: " "))
                                    .font(.monospaced(.caption)())
                            }

                            if let envs = config.Env {
                                Text(String(localized: "ENV:", table: "DockerManager"))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                ForEach(envs.prefix(5), id: \.self) { env in
                                    Text(env)
                                        .font(.monospaced(.caption)())
                                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                }
                                if envs.count > 5 {
                                    Text("... (+ \(envs.count - 5)) " + String(localized: "more", table: "DockerManager"))
                                        .font(.caption)
                                        .foregroundColor(Color(hex: "98989E"))
                                }
                            }
                        }
                        .padding()
                        .background(Material.regularMaterial)
                        .cornerRadius(8)
                    }
                }

                // History/Layers
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "History / Layers", table: "DockerManager"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                    ForEach(history) { layer in
                        HStack(alignment: .top) {
                            Text(layer.id.prefix(8))
                                .font(.monospaced(.caption)())
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                .frame(width: 60, alignment: .leading)

                            Text(layer.CreatedBy)
                                .font(.monospaced(.caption)())
                                .lineLimit(2)
                                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                            Spacer()

                            Text(layer.Size)
                                .font(.caption)
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        }
                        .padding(.vertical, 4)
                        GlassDivider()
                    }
                }
                .padding()
                .background(Material.regularMaterial)
                .cornerRadius(8)
            }
            .padding()
        }
        .background(Material.regularMaterial)
        .alert(String(localized: "Confirm Delete", table: "DockerManager"), isPresented: $showDeleteAlert) {
            Button(String(localized: "Cancel", table: "DockerManager"), role: .cancel) { }
            Button(String(localized: "Delete", table: "DockerManager"), role: .destructive) {
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
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
        }
    }
}

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
