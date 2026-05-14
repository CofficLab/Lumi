import Foundation
import LumiPreviewKit

@MainActor
final class EditorPreviewProjectPreviewIndexService {
    struct Snapshot {
        let rootURL: URL
        let scannedFileCount: Int
        let previewCount: Int
        let indexedAt: Date
    }

    private struct Entry: Sendable {
        let fileURL: URL
        let modifiedAt: Date?
        let fileSize: Int64
        let previews: [LumiPreviewPackage.PreviewDiscovery]
    }

    nonisolated private static let excludedDirectoryNames: Set<String> = [
        ".build", ".git", ".swiftpm", "DerivedData", "Pods", "build", "node_modules"
    ]
    nonisolated private static let maxSwiftFileCount = 3_000
    nonisolated private static let maxFileSize = 1_500_000

    var onSnapshotChanged: ((Snapshot?) -> Void)?

    private var rootURL: URL?
    private var entriesByPath: [String: Entry] = [:]
    private var previewCandidates: [LumiPreviewPackage.PreviewDiscovery] = []
    private var snapshot: Snapshot?
    private var indexTask: Task<Void, Never>?

    deinit {
        indexTask?.cancel()
    }

    func prepareIndex(projectRootPath: String?, currentFileURL: URL?) {
        guard let nextRootURL = Self.resolvedRootURL(projectRootPath: projectRootPath, currentFileURL: currentFileURL) else {
            reset()
            return
        }

        if rootURL?.standardizedFileURL.path != nextRootURL.standardizedFileURL.path {
            rootURL = nextRootURL
            entriesByPath = [:]
            snapshot = nil
            onSnapshotChanged?(nil)
            scheduleIndex(rootURL: nextRootURL, priorityFileURL: currentFileURL)
        } else if snapshot == nil, indexTask == nil {
            scheduleIndex(rootURL: nextRootURL, priorityFileURL: currentFileURL)
        }
    }

    func refreshCurrentFile(fileURL: URL, sourceText: String, previews: [LumiPreviewPackage.PreviewDiscovery]) {
        guard fileURL.pathExtension == "swift" else { return }
        guard let rootURL, fileURL.standardizedFileURL.path.hasPrefix(rootURL.standardizedFileURL.path) else { return }

        let metadata = Self.metadata(for: fileURL)
        entriesByPath[fileURL.standardizedFileURL.path] = Entry(
            fileURL: fileURL,
            modifiedAt: metadata.modifiedAt,
            fileSize: Int64(sourceText.utf8.count),
            previews: previews.withoutSourceText()
        )
        rebuildPreviewCandidates()
    }

    func cachedPreviews(for fileURL: URL) -> [LumiPreviewPackage.PreviewDiscovery]? {
        guard let entry = entriesByPath[fileURL.standardizedFileURL.path] else { return nil }
        let metadata = Self.metadata(for: fileURL)
        guard metadata.modifiedAt == entry.modifiedAt,
              metadata.fileSize == entry.fileSize else {
            return nil
        }
        return entry.previews
    }

    func bestPrewarmCandidate(preferredFileURL: URL?) -> LumiPreviewPackage.PreviewDiscovery? {
        prewarmCandidates(preferredFileURL: preferredFileURL, limit: 1).first
    }

    func prewarmCandidates(preferredFileURL: URL?, limit: Int) -> [LumiPreviewPackage.PreviewDiscovery] {
        guard limit > 0 else { return [] }

        var candidates: [LumiPreviewPackage.PreviewDiscovery] = []
        var seenIDs = Set<String>()

        if let preferredFileURL,
           let entry = entriesByPath[preferredFileURL.standardizedFileURL.path] {
            for preview in entry.previews where seenIDs.insert(preview.id).inserted {
                candidates.append(preview)
                if candidates.count >= limit {
                    return candidates
                }
            }
        }

        for preview in previewCandidates where seenIDs.insert(preview.id).inserted {
            candidates.append(preview)
            if candidates.count >= limit {
                break
            }
        }

        return candidates
    }

    private func reset() {
        indexTask?.cancel()
        indexTask = nil
        rootURL = nil
        entriesByPath = [:]
        previewCandidates = []
        snapshot = nil
        onSnapshotChanged?(nil)
    }

    private func scheduleIndex(rootURL: URL, priorityFileURL: URL?) {
        indexTask?.cancel()
        indexTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let result = await Self.scanProject(rootURL: rootURL, priorityFileURL: priorityFileURL)
            guard !Task.isCancelled else { return }
            self?.apply(result: result, rootURL: rootURL)
        }
    }

    private func apply(result: ScanResult, rootURL: URL) {
        guard self.rootURL?.standardizedFileURL.path == rootURL.standardizedFileURL.path else { return }
        entriesByPath = Dictionary(uniqueKeysWithValues: result.entries.map { ($0.fileURL.standardizedFileURL.path, $0) })
        previewCandidates = result.entries.flatMap(\.previews)
        snapshot = Snapshot(
            rootURL: rootURL,
            scannedFileCount: result.scannedFileCount,
            previewCount: result.entries.reduce(0) { $0 + $1.previews.count },
            indexedAt: Date()
        )
        indexTask = nil
        onSnapshotChanged?(snapshot)
    }

    private func rebuildPreviewCandidates() {
        previewCandidates = entriesByPath.values
            .sorted { $0.fileURL.path.localizedStandardCompare($1.fileURL.path) == .orderedAscending }
            .flatMap(\.previews)
    }

    nonisolated private static func resolvedRootURL(projectRootPath: String?, currentFileURL: URL?) -> URL? {
        if let projectRootPath, !projectRootPath.isEmpty {
            return URL(fileURLWithPath: projectRootPath, isDirectory: true)
        }
        return currentFileURL?.deletingLastPathComponent()
    }

    private struct ScanResult: Sendable {
        let entries: [Entry]
        let scannedFileCount: Int
    }

    nonisolated private static func scanProject(rootURL: URL, priorityFileURL: URL?) async -> ScanResult {
        await Task.detached(priority: .utility) {
            let fileURLs = swiftFileURLs(rootURL: rootURL, priorityFileURL: priorityFileURL)
            let scanner = LumiPreviewPackage.PreviewScanner()
            var entries: [Entry] = []

            for fileURL in fileURLs {
                guard !Task.isCancelled else { break }
                let metadata = metadata(for: fileURL)
                guard metadata.fileSize <= maxFileSize,
                      let sourceText = try? String(contentsOf: fileURL, encoding: .utf8),
                      sourceText.contains("#Preview") else {
                    continue
                }

                let previews = scanner.scan(fileURL: fileURL, sourceText: sourceText).withoutSourceText()
                entries.append(
                    Entry(
                        fileURL: fileURL,
                        modifiedAt: metadata.modifiedAt,
                        fileSize: metadata.fileSize,
                        previews: previews
                    )
                )
            }

            return ScanResult(entries: entries, scannedFileCount: fileURLs.count)
        }.value
    }

    nonisolated private static func swiftFileURLs(rootURL: URL, priorityFileURL: URL?) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let fileURL as URL in enumerator {
            guard urls.count < maxSwiftFileCount else { break }

            if isExcludedDirectory(fileURL) {
                enumerator.skipDescendants()
                continue
            }

            guard fileURL.pathExtension == "swift",
                  (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            urls.append(fileURL)
        }

        if let priorityFileURL,
           let index = urls.firstIndex(where: { $0.standardizedFileURL.path == priorityFileURL.standardizedFileURL.path }) {
            let priority = urls.remove(at: index)
            urls.insert(priority, at: 0)
        }
        return urls
    }

    nonisolated private static func isExcludedDirectory(_ url: URL) -> Bool {
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            return false
        }
        return excludedDirectoryNames.contains(url.lastPathComponent)
    }

    nonisolated private static func metadata(for fileURL: URL) -> (modifiedAt: Date?, fileSize: Int64) {
        let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return (
            modifiedAt: values?.contentModificationDate,
            fileSize: Int64(values?.fileSize ?? 0)
        )
    }
}

private extension Array where Element == LumiPreviewPackage.PreviewDiscovery {
    func withoutSourceText() -> [LumiPreviewPackage.PreviewDiscovery] {
        map { preview in
            LumiPreviewPackage.PreviewDiscovery(
                id: preview.id,
                title: preview.title,
                sourceFileURL: preview.sourceFileURL,
                lineNumber: preview.lineNumber,
                endLineNumber: preview.endLineNumber,
                primaryTypeName: preview.primaryTypeName,
                bodySource: preview.bodySource,
                sourceText: nil
            )
        }
    }
}
