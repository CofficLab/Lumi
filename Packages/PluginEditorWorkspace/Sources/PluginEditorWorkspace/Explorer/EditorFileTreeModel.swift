import Foundation

@MainActor
public final class EditorFileTreeModel: ObservableObject {
    @Published public private(set) var root: EditorFileTreeNode?
    @Published public private(set) var errorMessage: String?

    public static let defaultExcludedDirectoryNames: Set<String> = [
        ".git", ".build", "build", "DerivedData", "node_modules",
    ]

    private let excludedDirectoryNames: Set<String>
    private var loadingTasks: [URL: Task<Void, Never>] = [:]
    private var generation = UUID()

    public init(excludedDirectoryNames: Set<String> = defaultExcludedDirectoryNames) {
        self.excludedDirectoryNames = excludedDirectoryNames
    }

    deinit {
        for task in loadingTasks.values { task.cancel() }
    }

    public func setRoot(_ url: URL?) async {
        generation = UUID()
        let currentGeneration = generation
        for task in loadingTasks.values { task.cancel() }
        loadingTasks.removeAll()
        errorMessage = nil

        guard let url else {
            root = nil
            return
        }

        let normalized = url.standardizedFileURL
        let values = try? normalized.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values?.isDirectory == true else {
            root = nil
            errorMessage = "The selected project folder is unavailable."
            return
        }

        let rootNode = EditorFileTreeNode(entry: EditorFileTreeEntry(
            url: normalized,
            name: normalized.lastPathComponent,
            isDirectory: true,
            isSymbolicLink: values?.isSymbolicLink == true
        ))
        rootNode.isExpanded = true
        root = rootNode
        await loadChildren(of: rootNode, generation: currentGeneration)
    }

    public func toggle(_ node: EditorFileTreeNode) {
        guard node.canExpand else { return }
        node.isExpanded.toggle()
        guard node.isExpanded, node.children == nil else { return }
        scheduleLoadChildren(of: node)
    }

    public func expand(_ node: EditorFileTreeNode) async {
        guard node.canExpand else { return }
        node.isExpanded = true
        if node.children == nil {
            await loadChildren(of: node, generation: generation)
        }
    }

    public func refresh() async {
        guard let root else { return }
        let expandedURLs = collectExpandedURLs(from: root)
        await setRoot(root.url)
        guard let newRoot = self.root else { return }
        await restoreExpansions(expandedURLs, from: newRoot)
    }

    private func scheduleLoadChildren(of node: EditorFileTreeNode) {
        let url = node.url
        loadingTasks[url]?.cancel()
        let currentGeneration = generation
        loadingTasks[url] = Task { @MainActor [weak self, weak node] in
            guard let self, let node else { return }
            await self.loadChildren(of: node, generation: currentGeneration)
            self.loadingTasks[url] = nil
        }
    }

    private func loadChildren(of node: EditorFileTreeNode, generation: UUID) async {
        node.isLoading = true
        node.errorMessage = nil
        defer { node.isLoading = false }

        do {
            let entries = try await Self.enumerate(
                node.url,
                excludedDirectoryNames: excludedDirectoryNames
            )
            guard !Task.isCancelled, generation == self.generation else { return }
            node.children = entries.map(EditorFileTreeNode.init(entry:))
        } catch {
            guard !Task.isCancelled, generation == self.generation else { return }
            node.children = []
            node.errorMessage = error.localizedDescription
            if node === root { errorMessage = error.localizedDescription }
        }
    }

    nonisolated private static func enumerate(
        _ directory: URL,
        excludedDirectoryNames: Set<String>
    ) async throws -> [EditorFileTreeEntry] {
        try await Task.detached(priority: .userInitiated) {
            let keys: Set<URLResourceKey> = [
                .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isHiddenKey,
            ]
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsSubdirectoryDescendants]
            )

            return try urls.compactMap { url in
                try Task.checkCancellation()
                let values = try url.resourceValues(forKeys: keys)
                let isDirectory = values.isDirectory == true
                if isDirectory && excludedDirectoryNames.contains(url.lastPathComponent) {
                    return nil
                }
                guard isDirectory || values.isRegularFile == true || values.isSymbolicLink == true else {
                    return nil
                }
                return EditorFileTreeEntry(
                    url: url.standardizedFileURL,
                    name: url.lastPathComponent,
                    isDirectory: isDirectory,
                    isSymbolicLink: values.isSymbolicLink == true
                )
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory && !$1.isDirectory }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }.value
    }

    private func collectExpandedURLs(from node: EditorFileTreeNode) -> Set<URL> {
        var result: Set<URL> = node.isExpanded ? [node.url] : []
        for child in node.children ?? [] {
            result.formUnion(collectExpandedURLs(from: child))
        }
        return result
    }

    private func restoreExpansions(_ expandedURLs: Set<URL>, from node: EditorFileTreeNode) async {
        guard expandedURLs.contains(node.url), node.canExpand else { return }
        await expand(node)
        for child in node.children ?? [] {
            await restoreExpansions(expandedURLs, from: child)
        }
    }
}
