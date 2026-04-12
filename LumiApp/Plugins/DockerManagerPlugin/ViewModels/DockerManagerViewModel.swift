import Foundation
import Combine
import MagicKit

@MainActor
class DockerManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🐳"
    nonisolated static let verbose: Bool = false
    @Published var images: [DockerImage] = []
    @Published var filteredImages: [DockerImage] = []
    @Published var selectedImage: DockerImage?
    @Published var selectedImageDetail: DockerInspect?
    @Published var selectedImageHistory: [DockerImageHistory] = []
    @Published var scanResult: String?

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    
    // Sort
    enum SortOption {
        case created
        case size
        case name
    }
    @Published var sortOption: SortOption = .created
    @Published var sortDescending: Bool = true
    
    private let service = DockerService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Debounce search
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterAndSortImages()
            }
            .store(in: &cancellables)
            
        // React to sort changes
        $sortOption.combineLatest($sortDescending)
            .sink { [weak self] _, _ in
                self?.filterAndSortImages()
            }
            .store(in: &cancellables)
    }
    
    func refreshImages() async {
        if Self.verbose {
            DockerManagerPlugin.logger.info("\(self.t)刷新镜像列表")
        }
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await service.listImages()
            self.images = fetched
            filterAndSortImages()
            if Self.verbose {
                DockerManagerPlugin.logger.info("\(self.t)镜像列表刷新成功: \(fetched.count) 个镜像")
            }
        } catch {
            DockerManagerPlugin.logger.error("\(self.t)刷新镜像列表失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteImage(_ image: DockerImage, force: Bool = false) async {
        if Self.verbose {
            DockerManagerPlugin.logger.info("\(self.t)删除镜像: \(image.Repository)")
        }
        do {
            try await service.removeImage(image.imageID, force: force)
            // Remove locally to update UI immediately
            if let index = images.firstIndex(where: { $0.imageID == image.imageID }) {
                images.remove(at: index)
                filterAndSortImages()
            }
            if selectedImage?.imageID == image.imageID {
                selectedImage = nil
                selectedImageDetail = nil
            }
            if Self.verbose {
                DockerManagerPlugin.logger.info("\(self.t)镜像删除成功")
            }
        } catch {
            DockerManagerPlugin.logger.error("\(self.t)删除镜像失败: \(error.localizedDescription)")
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }

    func pullImage(_ name: String) async {
        if Self.verbose {
            DockerManagerPlugin.logger.info("\(self.t)拉取镜像: \(name)")
        }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await service.pullImage(name)
            await refreshImages()
        } catch {
            DockerManagerPlugin.logger.error("\(self.t)拉取镜像失败: \(error.localizedDescription)")
            errorMessage = "拉取失败: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func selectImage(_ image: DockerImage) async {
        selectedImage = image
        scanResult = nil // Clear previous scan

        if Self.verbose {
            DockerManagerPlugin.logger.info("\(self.t)选中镜像: \(image.Repository)")
        }

        // Fetch details in parallel
        async let detail = service.inspectImage(image.imageID)
        async let history = service.getImageHistory(image.imageID)

        do {
            let (d, h) = try await (detail, history)
            self.selectedImageDetail = d
            self.selectedImageHistory = h
        } catch {
            DockerManagerPlugin.logger.error("\(self.t)加载镜像详情失败: \(error.localizedDescription)")
        }
    }
    
    func tagImage(_ image: DockerImage, newTag: String) async {
        isLoading = true
        do {
            try await service.tagImage(image.imageID, target: newTag)
            await refreshImages()
        } catch {
            errorMessage = "Tag failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func exportImage(_ image: DockerImage, to url: URL) async {
        isLoading = true
        do {
            try await service.exportImage(image.imageID, to: url.path)
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func loadImage(from url: URL) async {
        isLoading = true
        do {
            try await service.loadImage(from: url.path)
            await refreshImages()
        } catch {
            errorMessage = "Load failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func scanImage(_ image: DockerImage) async {
        isLoading = true
        scanResult = "Scanning..."
        do {
            let result = try await service.scanImage(image.imageID)
            scanResult = result
        } catch {
            scanResult = "Scan failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func filterAndSortImages() {
        var result = images
        
        // Filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.Repository.localizedCaseInsensitiveContains(searchText) ||
                $0.Tag.localizedCaseInsensitiveContains(searchText) ||
                $0.imageID.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        result.sort { (a, b) -> Bool in
            switch sortOption {
            case .name:
                return sortDescending ? a.Repository > b.Repository : a.Repository < b.Repository
            case .size:
                // String comparison for now as Size is string (e.g. "10MB"), would need proper parsing for real sort
                return sortDescending ? a.Size > b.Size : a.Size < b.Size
            case .created:
                // CreatedAt is string "2023-..."
                return sortDescending ? a.CreatedAt > b.CreatedAt : a.CreatedAt < b.CreatedAt
            }
        }
        
        filteredImages = result
    }
}
