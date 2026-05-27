import AppKit
import Foundation

@MainActor
public final class AppIconArtifactStore: ObservableObject {
    public static let shared = AppIconArtifactStore()

    @Published public private(set) var artifacts: [AppIconArtifact] = []
    @Published public var selectedArtifactId: String?
    @Published public private(set) var lastExportURL: URL?
    @Published public private(set) var lastError: String?

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public var selectedArtifact: AppIconArtifact? {
        guard let selectedArtifactId else { return artifacts.first }
        return artifacts.first { $0.id == selectedArtifactId } ?? artifacts.first
    }

    public func registerImage(path: String, title: String? = nil, prompt: String? = nil) throws -> AppIconArtifact {
        let sourceURL = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw AppIconArtifactError.fileNotFound(path)
        }

        guard NSImage(contentsOf: sourceURL) != nil else {
            throw AppIconArtifactError.unsupportedImage(path)
        }

        let artifact = AppIconArtifact(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? sourceURL.deletingPathExtension().lastPathComponent,
            sourcePath: sourceURL.path,
            prompt: prompt?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )

        artifacts.insert(artifact, at: 0)
        selectedArtifactId = artifact.id
        lastError = nil
        return artifact
    }

    public func selectArtifact(id: String) {
        selectedArtifactId = id
    }

    public func setExportURL(_ url: URL) {
        lastExportURL = url
        lastError = nil
    }

    public func setError(_ message: String) {
        lastError = message
    }

    public func resetForTests() {
        artifacts.removeAll()
        selectedArtifactId = nil
        lastExportURL = nil
        lastError = nil
    }
}

public enum AppIconArtifactError: LocalizedError, Equatable {
    case fileNotFound(String)
    case unsupportedImage(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Image file not found: \(path)"
        case .unsupportedImage(let path):
            return "Unsupported image file: \(path)"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
