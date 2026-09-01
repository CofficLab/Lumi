import Foundation
import ProviderProject

public enum EditorPreviewState: Equatable, Sendable {
    case empty
    case loading(URL)
    case markdown(URL, String)
    case image(URL)
    case unsupported(URL)
    case failed(URL, String)

    /// Whether the root Content Footer should reserve space for this preview.
    public var showsPreviewFooter: Bool {
        switch self {
        case .loading, .markdown, .image, .failed:
            true
        case .empty, .unsupported:
            false
        }
    }
}

public enum EditorPreviewFileKind: Equatable, Sendable {
    case markdown
    case image
    case unsupported
}

/// View-facing state for the editor preview.
///
/// ProjectProviding remains the source of truth for the selected file. The
/// ViewModel owns file loading so the SwiftUI view only observes published
/// state and never reaches into a Provider directly.
@MainActor
public final class EditorPreviewViewModel: ObservableObject {
    @Published public private(set) var state: EditorPreviewState = .empty

    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    public init(project: any ProjectProviding) {
        updateCurrentFile(project.currentFileURL)
    }

    func updateCurrentFile(_ fileURL: URL?) {
        let normalizedURL = fileURL?.standardizedFileURL
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()

        guard let normalizedURL else {
            state = .empty
            return
        }

        switch Self.kind(for: normalizedURL) {
        case .markdown:
            state = .loading(normalizedURL)
        case .image:
            state = .image(normalizedURL)
            return
        case .unsupported:
            state = .unsupported(normalizedURL)
            return
        }

        loadTask = Task { [weak self] in
            do {
                let content = try await Self.readUTF8File(at: normalizedURL)
                guard !Task.isCancelled else { return }
                self?.apply(.markdown(normalizedURL, content), generation: generation)
            } catch {
                guard !Task.isCancelled else { return }
                self?.apply(
                    .failed(normalizedURL, error.localizedDescription),
                    generation: generation
                )
            }
        }
    }

    static func kind(for url: URL) -> EditorPreviewFileKind {
        let extensionName = url.pathExtension.lowercased()
        if ["md", "markdown", "mdown", "mkdn", "mkd"].contains(extensionName) {
            return .markdown
        }
        if ["png", "jpg", "jpeg", "gif", "webp", "tif", "tiff", "heic", "bmp"].contains(extensionName) {
            return .image
        }
        return .unsupported
    }

    private nonisolated static func readUTF8File(at url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try String(contentsOf: url, encoding: .utf8)
        }.value
    }

    private func apply(_ nextState: EditorPreviewState, generation: Int) {
        guard generation == loadGeneration else { return }
        state = nextState
    }
}
