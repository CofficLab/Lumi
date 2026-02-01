import Foundation
import Combine

@MainActor
class DockerManagerViewModel: ObservableObject {
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
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await service.listImages()
            self.images = fetched
            filterAndSortImages()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteImage(_ image: DockerImage, force: Bool = false) async {
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
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }
    
    func pullImage(_ name: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await service.pullImage(name)
            await refreshImages()
        } catch {
            errorMessage = "Pull failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func selectImage(_ image: DockerImage) async {
        selectedImage = image
        scanResult = nil // Clear previous scan
        // Fetch details in parallel
        async let detail = service.inspectImage(image.imageID)
        async let history = service.getImageHistory(image.imageID)
        
        do {
            let (d, h) = try await (detail, history)
            self.selectedImageDetail = d
            self.selectedImageHistory = h
        } catch {
            print("Failed to load details: \(error)")
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
