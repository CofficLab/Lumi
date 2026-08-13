import Combine
import Foundation
import KernelLumi

struct ProjectFilesState {
    static func visibleFileURLs(
        openFileURLs: [URL],
        currentFileURL: URL?
    ) -> [URL] {
        var orderedURLs: [URL] = []
        orderedURLs.reserveCapacity(openFileURLs.count + (currentFileURL == nil ? 0 : 1))

        func appendIfNeeded(_ url: URL) {
            let standardizedURL = url.standardizedFileURL
            if !orderedURLs.contains(standardizedURL) {
                orderedURLs.append(standardizedURL)
            }
        }

        for fileURL in openFileURLs {
            appendIfNeeded(fileURL)
        }

        if let currentFileURL {
            appendIfNeeded(currentFileURL)
        }

        return orderedURLs
    }
}

@MainActor
final class ProjectFilesProjectObserver: ObservableObject {
    private var cancellable: AnyCancellable?

    var project: (any ProjectProviding)? {
        didSet {
            bind()
        }
    }

    init(project: (any ProjectProviding)?) {
        self.project = project
        bind()
    }

    private func bind() {
        cancellable = nil
        guard let project else { return }
        cancellable = project.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
