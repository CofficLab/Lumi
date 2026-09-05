import AppKit
import Foundation

/// Directory tree analysis service.
public final class DirectoryTreeService: @unchecked Sendable {
    public static let shared = DirectoryTreeService()
    private let coordinator = DirectoryTreeScanCoordinator()

    init() {}

    public func scanDirectoryTree(atPath path: String) async throws -> [DirectoryEntry] {
        try await coordinator.scan(path: path, mode: .fullTree)
    }

    /// Returns only the immediate children of `path` with recursively aggregated
    /// sizes. This is the cheap representation needed by the Agent tool; it
    /// deliberately does not materialize every file in the tree.
    public func scanTopLevelDirectoryUsage(
        atPath path: String,
        maxEntries: Int = 500_000,
        maxDuration: TimeInterval = 30,
        onProgress: (@Sendable (ScanProgress) async -> Void)? = nil
    ) async throws -> [DirectoryEntry] {
        try await coordinator.scan(
            path: path,
            mode: .topLevelSummary(maxEntries: maxEntries, maxDuration: maxDuration),
            onProgress: onProgress
        )
    }

    public func progressStream() async -> AsyncStream<ScanProgress> {
        await coordinator.progressStream()
    }

    public func cancelScan() async {
        await coordinator.cancelCurrentScan()
    }

    @MainActor
    public func revealInFinder(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

enum DirectoryTreeScanError: LocalizedError {
    case budgetExceeded(scannedEntries: Int, currentPath: String)

    var errorDescription: String? {
        switch self {
        case .budgetExceeded(let scannedEntries, let currentPath):
            return "The scan reached its safety limit after \(scannedEntries) entries near \(currentPath). Narrow the path and try again."
        }
    }
}

// MARK: - Coordinator

actor DirectoryTreeScanCoordinator {
    enum Mode {
        case fullTree
        case topLevelSummary(maxEntries: Int, maxDuration: TimeInterval)
    }

    private var activeToken: DirectoryTreeScanCancellationToken?
    private var currentProgress: ScanProgress? {
        didSet {
            if let progress = currentProgress {
                for (_, continuation) in progressContinuations {
                    continuation.yield(progress)
                }
            }
        }
    }
    private var progressContinuations: [UUID: AsyncStream<ScanProgress>.Continuation] = [:]

    func progressStream() -> AsyncStream<ScanProgress> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { await self.addContinuation(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    private func addContinuation(id: UUID, continuation: AsyncStream<ScanProgress>.Continuation) {
        progressContinuations[id] = continuation
        if let currentProgress {
            continuation.yield(currentProgress)
        }
    }

    private func removeContinuation(id: UUID) {
        progressContinuations[id] = nil
    }

    func scan(
        path: String,
        mode: Mode,
        onProgress: (@Sendable (ScanProgress) async -> Void)? = nil
    ) async throws -> [DirectoryEntry] {
        activeToken?.cancel()

        let token = DirectoryTreeScanCancellationToken()
        activeToken = token
        let normalizedPath = URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let start = Date()

        await publish(
            ScanProgress(
                path: normalizedPath,
                currentPath: normalizedPath,
                scannedFiles: 0,
                scannedDirectories: 0,
                scannedBytes: 0,
                startTime: start
            ),
            to: onProgress
        )

        do {
            let result = try await withTaskCancellationHandler(operation: {
                switch mode {
                case .fullTree:
                    return try await Self.buildTree(
                        rootPath: normalizedPath,
                        token: token,
                        start: start,
                        progress: { [weak self] progress in
                            await self?.publish(progress, to: onProgress)
                        }
                    )
                case .topLevelSummary(let maxEntries, let maxDuration):
                    return try await Self.buildTopLevelSummary(
                        rootPath: normalizedPath,
                        token: token,
                        maxEntries: maxEntries,
                        maxDuration: maxDuration,
                        start: start,
                        progress: { [weak self] progress in
                            await self?.publish(progress, to: onProgress)
                        }
                    )
                }
            }, onCancel: {
                token.cancel()
            })

            try Task.checkCancellation()
            guard !token.isCancelled else { throw CancellationError() }
            currentProgress = nil
            activeToken = nil
            finishAllProgressStreams()
            return result
        } catch {
            if activeToken === token {
                activeToken = nil
            }
            currentProgress = nil
            finishAllProgressStreams()
            throw error
        }
    }

    func cancelCurrentScan() {
        activeToken?.cancel()
        activeToken = nil
        currentProgress = nil
        finishAllProgressStreams()
    }

    private func publish(
        _ progress: ScanProgress,
        to onProgress: (@Sendable (ScanProgress) async -> Void)?
    ) async {
        currentProgress = progress
        await onProgress?(progress)
    }

    private static func buildTopLevelSummary(
        rootPath: String,
        token: DirectoryTreeScanCancellationToken,
        maxEntries: Int,
        maxDuration: TimeInterval,
        start: Date,
        progress: @escaping @Sendable (ScanProgress) async -> Void
    ) async throws -> [DirectoryEntry] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath)
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var summaries: [String: SummaryNode] = [:]
        var scannedFiles = 0
        var scannedDirectories = 0
        var scannedBytes: Int64 = 0
        var lastPath = rootPath
        var lastEmitAt = Date.distantPast

        while let url = enumerator.nextObject() as? URL {
            try checkCancellation(token)
            let normalizedURLPath = pathUsingRootAlias(url.path, rootPath: rootPath)
            lastPath = normalizedURLPath

            if Date().timeIntervalSince(start) >= maxDuration ||
                scannedFiles + scannedDirectories >= maxEntries {
                throw DirectoryTreeScanError.budgetExceeded(
                    scannedEntries: scannedFiles + scannedDirectories,
                    currentPath: lastPath
                )
            }

            guard let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .isPackageKey, .fileSizeKey]
            ) else { continue }

            let isDirectory = values.isDirectory ?? false
            let isPackage = values.isPackage ?? false
            let treatedAsDirectory = isDirectory && !isPackage
            let size = Int64(values.fileSize ?? 0)
            let topLevelPath = immediateChildPath(of: normalizedURLPath, rootPath: rootPath)

            if treatedAsDirectory {
                scannedDirectories += 1
            } else {
                scannedFiles += 1
                scannedBytes += size
            }

            var summary = summaries[topLevelPath] ?? SummaryNode(
                path: topLevelPath,
                isDirectory: topLevelPath != url.path || treatedAsDirectory
            )
            if !treatedAsDirectory {
                summary.size += size
            }
            summaries[topLevelPath] = summary

            let now = Date()
            if now.timeIntervalSince(lastEmitAt) >= 0.5 {
                lastEmitAt = now
                await progress(
                    ScanProgress(
                        path: rootPath,
                        currentPath: lastPath,
                        scannedFiles: scannedFiles,
                        scannedDirectories: scannedDirectories,
                        scannedBytes: scannedBytes,
                        startTime: start
                    )
                )
            }
        }

        try checkCancellation(token)
        await progress(
            ScanProgress(
                path: rootPath,
                currentPath: lastPath,
                scannedFiles: scannedFiles,
                scannedDirectories: scannedDirectories,
                scannedBytes: scannedBytes,
                startTime: start
            )
        )

        return summaries.values
            .map { summary in
                DirectoryEntry(
                    id: UUID().uuidString,
                    name: URL(fileURLWithPath: summary.path).lastPathComponent,
                    path: summary.path,
                    size: summary.size,
                    isDirectory: summary.isDirectory,
                    lastAccessed: Date(),
                    modificationDate: Date(),
                    children: summary.isDirectory ? [] : nil
                )
            }
            .sorted { $0.size > $1.size }
    }

    private static func buildTree(
        rootPath: String,
        token: DirectoryTreeScanCancellationToken,
        start: Date,
        progress: @escaping @Sendable (ScanProgress) async -> Void
    ) async throws -> [DirectoryEntry] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath)
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isPackageKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .contentAccessDateKey,
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let root = MutableScanNode(path: rootPath, isDirectory: true)
        var nodes: [String: MutableScanNode] = [rootPath: root]
        var scannedFiles = 0
        var scannedDirectories = 0
        var scannedBytes: Int64 = 0
        var lastPath = rootPath
        var lastEmitAt = Date.distantPast

        while let url = enumerator.nextObject() as? URL {
            try checkCancellation(token)
            let normalizedURLPath = pathUsingRootAlias(url.path, rootPath: rootPath)
            lastPath = normalizedURLPath

            guard let values = try? url.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isPackageKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .contentAccessDateKey,
                ]
            ) else { continue }

            let isDirectory = values.isDirectory ?? false
            let isPackage = values.isPackage ?? false
            let treatedAsDirectory = isDirectory && !isPackage
            let size = Int64(values.fileSize ?? 0)
            let node = nodes[normalizedURLPath] ?? MutableScanNode(
                path: normalizedURLPath,
                isDirectory: treatedAsDirectory,
                lastAccessed: values.contentAccessDate ?? Date(),
                modificationDate: values.contentModificationDate ?? Date()
            )
            node.isDirectory = treatedAsDirectory
            node.size = treatedAsDirectory ? node.size : size
            node.lastAccessed = values.contentAccessDate ?? node.lastAccessed
            node.modificationDate = values.contentModificationDate ?? node.modificationDate
            nodes[normalizedURLPath] = node

            let parentPath = URL(fileURLWithPath: normalizedURLPath).deletingLastPathComponent().path
            let parent = ensureDirectoryNode(path: parentPath, rootPath: rootPath, nodes: &nodes)
            parent.children[normalizedURLPath] = node

            if treatedAsDirectory {
                scannedDirectories += 1
            } else {
                scannedFiles += 1
                scannedBytes += size
            }

            let now = Date()
            if now.timeIntervalSince(lastEmitAt) >= 0.5 {
                lastEmitAt = now
                await progress(
                    ScanProgress(
                        path: rootPath,
                        currentPath: lastPath,
                        scannedFiles: scannedFiles,
                        scannedDirectories: scannedDirectories,
                        scannedBytes: scannedBytes,
                        startTime: start
                    )
                )
            }
        }

        let nodesByDepth = nodes.values.sorted {
            $0.path.split(separator: "/").count > $1.path.split(separator: "/").count
        }
        for node in nodesByDepth where node.path != rootPath && node.isDirectory {
            try checkCancellation(token)
            let parentPath = URL(fileURLWithPath: node.path).deletingLastPathComponent().path
            nodes[parentPath]?.size += node.size
        }

        var built: [String: DirectoryEntry] = [:]
        for node in nodesByDepth {
            try checkCancellation(token)
            let children = node.children.values
                .compactMap { built[$0.path] }
                .sorted { $0.size > $1.size }
            built[node.path] = DirectoryEntry(
                id: UUID().uuidString,
                name: URL(fileURLWithPath: node.path).lastPathComponent,
                path: node.path,
                size: node.size,
                isDirectory: node.isDirectory,
                lastAccessed: node.lastAccessed,
                modificationDate: node.modificationDate,
                children: node.isDirectory ? children : nil
            )
        }

        try checkCancellation(token)
        await progress(
            ScanProgress(
                path: rootPath,
                currentPath: lastPath,
                scannedFiles: scannedFiles,
                scannedDirectories: scannedDirectories,
                scannedBytes: scannedBytes,
                startTime: start
            )
        )
        return root.children.values.compactMap { built[$0.path] }.sorted { $0.size > $1.size }
    }

    private static func ensureDirectoryNode(
        path: String,
        rootPath: String,
        nodes: inout [String: MutableScanNode]
    ) -> MutableScanNode {
        if let existing = nodes[path] { return existing }
        let node = MutableScanNode(path: path, isDirectory: true)
        nodes[path] = node
        if path != rootPath {
            let parentPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
            let parent = ensureDirectoryNode(path: parentPath, rootPath: rootPath, nodes: &nodes)
            parent.children[path] = node
        }
        return node
    }

    private static func immediateChildPath(of path: String, rootPath: String) -> String {
        let rootComponents = comparablePathComponents(rootPath)
        let pathComponents = comparablePathComponents(path)
        guard pathComponents.count > rootComponents.count,
              Array(pathComponents.prefix(rootComponents.count)) == rootComponents,
              let first = pathComponents.dropFirst(rootComponents.count).first else {
            return path
        }
        return URL(fileURLWithPath: rootPath).appendingPathComponent(first).path
    }

    private static func pathUsingRootAlias(_ path: String, rootPath: String) -> String {
        let rootComponents = comparablePathComponents(rootPath)
        let pathComponents = comparablePathComponents(path)
        guard pathComponents.count >= rootComponents.count,
              Array(pathComponents.prefix(rootComponents.count)) == rootComponents else {
            return path
        }
        let relativeComponents = pathComponents.dropFirst(rootComponents.count)
        guard !relativeComponents.isEmpty else { return rootPath }
        return relativeComponents.reduce(URL(fileURLWithPath: rootPath)) { url, component in
            url.appendingPathComponent(component)
        }.path
    }

    private static func comparablePathComponents(_ path: String) -> [String] {
        let components = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
        // macOS may expose /var through /private/var depending on which API
        // produced the URL. Treat the two aliases as the same scan root.
        if components.count > 1, components[1] == "private" {
            return [components[0]] + components.dropFirst(2)
        }
        return components
    }

    private static func checkCancellation(_ token: DirectoryTreeScanCancellationToken) throws {
        try Task.checkCancellation()
        if token.isCancelled { throw CancellationError() }
    }

    private func finishAllProgressStreams() {
        for (_, continuation) in progressContinuations {
            continuation.finish()
        }
        progressContinuations.removeAll()
    }
}

private final class DirectoryTreeScanCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func cancel() {
        lock.lock()
        value = true
        lock.unlock()
    }
}

private final class MutableScanNode {
    let path: String
    var isDirectory: Bool
    var size: Int64 = 0
    var lastAccessed: Date
    var modificationDate: Date
    var children: [String: MutableScanNode] = [:]

    init(
        path: String,
        isDirectory: Bool,
        lastAccessed: Date = Date(),
        modificationDate: Date = Date()
    ) {
        self.path = path
        self.isDirectory = isDirectory
        self.lastAccessed = lastAccessed
        self.modificationDate = modificationDate
    }
}

private struct SummaryNode {
    let path: String
    let isDirectory: Bool
    var size: Int64 = 0
}
