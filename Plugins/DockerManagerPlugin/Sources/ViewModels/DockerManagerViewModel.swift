import Foundation
import Combine
import SuperLogKit

protocol DockerManagerServicing: Sendable {
    func listImages() async throws -> [DockerImage]
    func removeImage(_ id: String, force: Bool) async throws
    func pullImage(_ name: String) async throws -> String
    func inspectImage(_ id: String) async throws -> DockerInspect
    func getImageHistory(_ id: String) async throws -> [DockerImageHistory]
    func tagImage(_ id: String, target: String) async throws
    func exportImage(_ id: String, to path: String) async throws
    func loadImage(from path: String) async throws
    func scanImage(_ id: String) async throws -> String
}

struct LiveDockerManagerService: DockerManagerServicing {
    private let service: DockerService

    init(service: DockerService = .shared) {
        self.service = service
    }

    func listImages() async throws -> [DockerImage] {
        try await service.listImages()
    }

    func removeImage(_ id: String, force: Bool) async throws {
        try await service.removeImage(id, force: force)
    }

    func pullImage(_ name: String) async throws -> String {
        try await service.pullImage(name)
    }

    func inspectImage(_ id: String) async throws -> DockerInspect {
        try await service.inspectImage(id)
    }

    func getImageHistory(_ id: String) async throws -> [DockerImageHistory] {
        try await service.getImageHistory(id)
    }

    func tagImage(_ id: String, target: String) async throws {
        try await service.tagImage(id, target: target)
    }

    func exportImage(_ id: String, to path: String) async throws {
        try await service.exportImage(id, to: path)
    }

    func loadImage(from path: String) async throws {
        try await service.loadImage(from: path)
    }

    func scanImage(_ id: String) async throws -> String {
        try await service.scanImage(id)
    }
}

enum DockerImageReferenceValidator {
    static func normalizedReference(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 255 else { return nil }
        guard trimmed.first != "-" else { return nil }
        guard trimmed.unicodeScalars.allSatisfy(isAllowedReferenceScalar) else { return nil }
        guard trimmed.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty }) else { return nil }
        return trimmed
    }

    static func isValidReference(_ value: String) -> Bool {
        normalizedReference(value) != nil
    }

    private static func isAllowedReferenceScalar(_ scalar: Unicode.Scalar) -> Bool {
        (scalar.value >= 48 && scalar.value <= 57)
            || (scalar.value >= 65 && scalar.value <= 90)
            || (scalar.value >= 97 && scalar.value <= 122)
            || scalar == "."
            || scalar == "_"
            || scalar == "-"
            || scalar == "/"
            || scalar == ":"
            || scalar == "@"
    }
}

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
    
    private let service: any DockerManagerServicing
    private var imageDetailsTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    init(service: any DockerManagerServicing = LiveDockerManagerService()) {
        self.service = service

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
            if DockerManagerPlugin.verbose {
                DockerManagerPlugin.logger.info("\(self.t)刷新镜像列表")
            }
        }
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await service.listImages()
            self.images = fetched
            filterAndSortImages()
            if Self.verbose {
                if DockerManagerPlugin.verbose {
                    DockerManagerPlugin.logger.info("\(self.t)镜像列表刷新成功: \(fetched.count) 个镜像")
                }
            }
        } catch {
            if DockerManagerPlugin.verbose {
                DockerManagerPlugin.logger.error("\(self.t)刷新镜像列表失败: \(error.localizedDescription)")
            }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteImage(_ image: DockerImage, force: Bool = false) async {
        if Self.verbose {
            if DockerManagerPlugin.verbose {
                DockerManagerPlugin.logger.info("\(self.t)删除镜像: \(image.repository)")
            }
        }
        errorMessage = nil
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
                if DockerManagerPlugin.verbose {
                    DockerManagerPlugin.logger.info("\(self.t)镜像删除成功")
                }
            }
        } catch {
            if DockerManagerPlugin.verbose {
                DockerManagerPlugin.logger.error("\(self.t)删除镜像失败: \(error.localizedDescription)")
            }
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func pullImage(_ name: String) async -> Bool {
        guard let normalizedName = DockerImageReferenceValidator.normalizedReference(name) else {
            errorMessage = "Invalid image name"
            return false
        }

        if Self.verbose {
            if DockerManagerPlugin.verbose {
                DockerManagerPlugin.logger.info("\(self.t)拉取镜像: \(normalizedName)")
            }
        }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await service.pullImage(normalizedName)
            await refreshImages()
            isLoading = false
            return true
        } catch {
            if DockerManagerPlugin.verbose {
                DockerManagerPlugin.logger.error("\(self.t)拉取镜像失败: \(error.localizedDescription)")
            }
            errorMessage = "拉取失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func selectImage(_ image: DockerImage) async {
        imageDetailsTask?.cancel()
        selectedImage = image
        selectedImageDetail = nil
        selectedImageHistory = []
        scanResult = nil // Clear previous scan
        errorMessage = nil
        let selectedImageID = image.imageID

        if Self.verbose {
            if DockerManagerPlugin.verbose {
                DockerManagerPlugin.logger.info("\(self.t)选中镜像: \(image.repository)")
            }
        }

        let task = Task { [service, selectedImageID] in
            do {
                // Fetch details in parallel
                async let detail = service.inspectImage(selectedImageID)
                async let history = service.getImageHistory(selectedImageID)
                let (d, h) = try await (detail, history)

                await MainActor.run {
                    guard !Task.isCancelled, self.selectedImage?.imageID == selectedImageID else { return }
                    self.selectedImageDetail = d
                    self.selectedImageHistory = h
                    self.imageDetailsTask = nil
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled, self.selectedImage?.imageID == selectedImageID else { return }
                    if DockerManagerPlugin.verbose {
                        DockerManagerPlugin.logger.error("\(self.t)加载镜像详情失败: \(error.localizedDescription)")
                    }
                    self.errorMessage = "Load details failed: \(error.localizedDescription)"
                    self.imageDetailsTask = nil
                }
            }
        }
        imageDetailsTask = task
        await task.value
    }
    
    @discardableResult
    func tagImage(_ image: DockerImage, newTag: String) async -> Bool {
        guard let normalizedTag = DockerImageReferenceValidator.normalizedReference(newTag) else {
            errorMessage = "Invalid image tag"
            return false
        }

        isLoading = true
        errorMessage = nil
        do {
            try await service.tagImage(image.imageID, target: normalizedTag)
            await refreshImages()
            isLoading = false
            return true
        } catch {
            errorMessage = "Tag failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func exportImage(_ image: DockerImage, to url: URL) async {
        isLoading = true
        errorMessage = nil
        do {
            try await service.exportImage(image.imageID, to: url.path)
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func loadImage(from url: URL) async {
        isLoading = true
        errorMessage = nil
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
        errorMessage = nil
        scanResult = "Scanning..."
        do {
            let result = try await service.scanImage(image.imageID)
            scanResult = result
        } catch {
            scanResult = "Scan failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func reportFilePanelError(_ action: String, error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
            return
        }
        errorMessage = "\(action): \(error.localizedDescription)"
    }

    deinit {
        imageDetailsTask?.cancel()
    }
    
    private func filterAndSortImages() {
        var result = images
        
        // Filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.repository.localizedCaseInsensitiveContains(searchText) ||
                $0.tag.localizedCaseInsensitiveContains(searchText) ||
                $0.imageID.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        result.sort { (a, b) -> Bool in
            switch sortOption {
            case .name:
                return sortDescending ? a.repository > b.repository : a.repository < b.repository
            case .size:
                return sortDescending ? a.sizeBytes > b.sizeBytes : a.sizeBytes < b.sizeBytes
            case .created:
                // createdAt is string "2023-..."
                return sortDescending ? a.createdAt > b.createdAt : a.createdAt < b.createdAt
            }
        }
        
        filteredImages = result
    }
}
