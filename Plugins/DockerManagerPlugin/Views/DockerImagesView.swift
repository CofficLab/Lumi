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
                    TextField("搜索镜像...", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)

                    Menu {
                        Picker("排序", selection: $viewModel.sortOption) {
                            Text("创建时间").tag(DockerManagerViewModel.SortOption.created)
                            Text("名称").tag(DockerManagerViewModel.SortOption.name)
                            Text("大小").tag(DockerManagerViewModel.SortOption.size)
                        }
                        Toggle("降序", isOn: $viewModel.sortDescending)
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }

                    Button(action: {
                        Task { await viewModel.refreshImages() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

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

                Divider()

                // Footer
                HStack {
                    Text("\(viewModel.filteredImages.count) 个镜像")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: { showFileImporter = true }) {
                        Label("导入", systemImage: "square.and.arrow.down")
                    }
                    Button(action: { showPullSheet = true }) {
                        Label("拉取", systemImage: "arrow.down.circle")
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .frame(minWidth: 250, maxWidth: 400)

            // Detail View
            if let selected = viewModel.selectedImage {
                DockerImageDetailView(image: selected, detail: viewModel.selectedImageDetail, history: viewModel.selectedImageHistory, viewModel: viewModel)
            } else {
                VStack {
                    Image(systemName: "cube.box")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("选择一个镜像查看详情")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .sheet(isPresented: $showPullSheet) {
            VStack(spacing: 20) {
                Text("拉取新镜像")
                    .font(.headline)
                TextField("镜像名称 (例如: nginx:latest)", text: $pullImageName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                if viewModel.isLoading {
                    ProgressView("Pulling...")
                }

                HStack {
                    Button("取消") { showPullSheet = false }
                    Button("拉取") {
                        Task {
                            await viewModel.pullImage(pullImageName)
                            showPullSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pullImageName.isEmpty || viewModel.isLoading)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showTagSheet) {
            VStack(spacing: 20) {
                Text("Tag 镜像")
                    .font(.headline)
                if let img = imageToTag {
                    Text("源: \(img.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("新 Tag (例如: myrepo:v1)", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                HStack {
                    Button("取消") { showTagSheet = false }
                    Button("确认") {
                        if let img = imageToTag {
                            Task {
                                await viewModel.tagImage(img, newTag: newTag)
                                showTagSheet = false
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
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
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(image.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(image.shortID)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(image.Size)
                    .font(.caption)
                Text(image.CreatedSince)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                        HStack {
                            Text(image.Tag)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                            Text(image.imageID)
                                .font(.monospaced(.caption)())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()

                    Button(action: {
                        Task { await viewModel.scanImage(image) }
                    }) {
                        Label("Scan", systemImage: "checkerboard.shield")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { showDeleteAlert = true }) {
                        Label("删除", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Scan Result
                if let scanResult = viewModel.scanResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Security Scan")
                            .font(.headline)

                        ScrollView([.horizontal, .vertical]) {
                            Text(scanResult)
                                .font(.monospaced(.caption)())
                                .padding()
                        }
                        .frame(maxHeight: 200)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(4)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
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
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    // Config
                    if let config = detail.Config {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Configuration")
                                .font(.headline)

                            if let cmds = config.Cmd {
                                Text("CMD: " + cmds.joined(separator: " "))
                                    .font(.monospaced(.caption)())
                            }

                            if let envs = config.Env {
                                Text("ENV:")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                ForEach(envs.prefix(5), id: \.self) { env in
                                    Text(env)
                                        .font(.monospaced(.caption)())
                                        .foregroundStyle(.secondary)
                                }
                                if envs.count > 5 {
                                    Text("... (+ \(envs.count - 5) more)")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }

                // History/Layers
                VStack(alignment: .leading, spacing: 8) {
                    Text("History / Layers")
                        .font(.headline)

                    ForEach(history) { layer in
                        HStack(alignment: .top) {
                            Text(layer.id.prefix(8))
                                .font(.monospaced(.caption)())
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)

                            Text(layer.CreatedBy)
                                .font(.monospaced(.caption)())
                                .lineLimit(2)

                            Spacer()

                            Text(layer.Size)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task { await viewModel.deleteImage(image) }
            }
        } message: {
            Text("确定要删除镜像 \(image.name) 吗？此操作不可撤销。")
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
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(DockerManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
