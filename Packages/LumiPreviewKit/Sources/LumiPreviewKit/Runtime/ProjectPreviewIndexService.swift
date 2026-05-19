import Darwin
import Foundation

extension LumiPreviewFacade {
  /// 项目预览索引服务：扫描项目目录中的 Swift 源文件，发现所有 `#Preview` 宏声明。
  ///
  /// 功能：
  /// - 递归扫描项目目录下的 `.swift` 文件
  /// - 使用 `PreviewScanner` 提取所有 `#Preview` 声明
  /// - 通过文件系统监控（kqueue）监听目录变化，自动增量更新索引
  /// - 提供预览预热候选排序，优先处理当前活跃文件
  ///
  /// 典型流程：
  /// 1. `prepareIndex(projectRootPath:)` — 触发全量扫描
  /// 2. `refreshCurrentFile(fileURL:sourceText:previews:)` — 增量更新当前文件
  /// 3. `prewarmCandidates(preferredFileURL:limit:)` — 获取预热候选列表
  @MainActor
  public final class ProjectPreviewIndexService {
    /// 索引快照：某一时刻的项目扫描统计摘要。
    public struct Snapshot {
        /// 项目根目录。
        public let rootURL: URL
        /// 已扫描的 Swift 文件数。
        public let scannedFileCount: Int
        /// 发现的 `#Preview` 数量。
        public let previewCount: Int
        /// 快照生成时间。
        public let indexedAt: Date

      public init(rootURL: URL, scannedFileCount: Int, previewCount: Int, indexedAt: Date) {
        self.rootURL = rootURL
        self.scannedFileCount = scannedFileCount
        self.previewCount = previewCount
        self.indexedAt = indexedAt
      }
    }

    private struct Entry: Sendable {
      let fileURL: URL
      let modifiedAt: Date?
      let fileSize: Int64
      let sourceFingerprint: Int
      let previews: [LumiPreviewFacade.PreviewDiscovery]
    }

    private struct Watch: @unchecked Sendable {
      let fileDescriptor: Int32
      let source: DispatchSourceProtocol
    }

    nonisolated private static let excludedDirectoryNames: Set<String> = [
      ".build", ".git", ".swiftpm", "DerivedData", "Pods", "build", "node_modules",
    ]
    nonisolated private static let maxSwiftFileCount = 3_000
    nonisolated private static let maxFileSize = 1_500_000
    nonisolated private static let maxWatchedDirectoryCount = 512

    public var onSnapshotChanged: ((Snapshot?) -> Void)?

    private var rootURL: URL?
    private var entriesByPath: [String: Entry] = [:]
    private var indexedSwiftFilePaths: Set<String> = []
    private var previewCandidates: [LumiPreviewFacade.PreviewDiscovery] = []
    private var snapshot: Snapshot?
    private var indexTask: Task<Void, Never>?
    private var incrementalIndexTasks: [String: Task<Void, Never>] = [:]
    private var directoryWatches: [String: Watch] = [:]

    public init() {}

    deinit {
      indexTask?.cancel()
      incrementalIndexTasks.values.forEach { $0.cancel() }
      for watch in directoryWatches.values {
        watch.source.cancel()
      }
    }

    public func prepareIndex(projectRootPath: String?, currentFileURL: URL?) {
      guard
        let nextRootURL = Self.resolvedRootURL(
          projectRootPath: projectRootPath, currentFileURL: currentFileURL)
      else {
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

    public func refreshCurrentFile(
      fileURL: URL,
      sourceText: String,
      previews: [LumiPreviewFacade.PreviewDiscovery]
    ) {
      guard fileURL.pathExtension == "swift" else { return }
      guard let rootURL,
        fileURL.standardizedFileURL.path.hasPrefix(rootURL.standardizedFileURL.path)
      else { return }

      let metadata = Self.metadata(for: fileURL)
      indexedSwiftFilePaths.insert(fileURL.standardizedFileURL.path)
      entriesByPath[fileURL.standardizedFileURL.path] = Entry(
        fileURL: fileURL,
        modifiedAt: metadata.modifiedAt,
        fileSize: Int64(sourceText.utf8.count),
        sourceFingerprint: Self.sourceFingerprint(sourceText),
        previews: previews.strippingSourceText()
      )
      rebuildPreviewCandidates()
      updateSnapshot()
      updateDirectoryWatches(rootURL: rootURL)
    }

    public func cachedPreviews(for fileURL: URL) -> [LumiPreviewFacade.PreviewDiscovery]? {
      guard let entry = entriesByPath[fileURL.standardizedFileURL.path] else { return nil }
      let metadata = Self.metadata(for: fileURL)
      guard metadata.modifiedAt == entry.modifiedAt,
        metadata.fileSize == entry.fileSize
      else {
        guard
          metadata.fileSize == entry.fileSize,
          let sourceText = try? String(contentsOf: fileURL, encoding: .utf8),
          Self.sourceFingerprint(sourceText) == entry.sourceFingerprint
        else {
          return nil
        }
        return entry.previews
      }
      return entry.previews
    }

    nonisolated private static func sourceFingerprint(_ sourceText: String) -> Int {
      sourceText.hashValue
    }

    public func bestPrewarmCandidate(preferredFileURL: URL?) -> LumiPreviewFacade.PreviewDiscovery?
    {
      prewarmCandidates(preferredFileURL: preferredFileURL, limit: 1).first
    }

    public func prewarmCandidates(
      preferredFileURL: URL?,
      limit: Int
    ) -> [LumiPreviewFacade.PreviewDiscovery] {
      guard limit > 0 else { return [] }

      var candidates: [LumiPreviewFacade.PreviewDiscovery] = []
      var seenIDs = Set<String>()

      if let preferredFileURL,
        let entry = entriesByPath[preferredFileURL.standardizedFileURL.path]
      {
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
      incrementalIndexTasks.values.forEach { $0.cancel() }
      incrementalIndexTasks = [:]
      stopDirectoryWatches()
      rootURL = nil
      entriesByPath = [:]
      indexedSwiftFilePaths = []
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
      guard self.rootURL?.standardizedFileURL.path == rootURL.standardizedFileURL.path else {
        return
      }
      entriesByPath = Dictionary(
        uniqueKeysWithValues: result.entries.map {
          ($0.fileURL.standardizedFileURL.path, $0)
        })
      indexedSwiftFilePaths = Set(result.scannedSwiftFileURLs.map { $0.standardizedFileURL.path })
      previewCandidates = result.entries.flatMap(\.previews)
      updateSnapshot()
      indexTask = nil
      updateDirectoryWatches(rootURL: rootURL)
      onSnapshotChanged?(snapshot)
    }

    private func scheduleIncrementalIndex(directoryURL: URL) {
      guard let rootURL else { return }
      let directoryPath = directoryURL.standardizedFileURL.path
      incrementalIndexTasks[directoryPath]?.cancel()
      incrementalIndexTasks[directoryPath] = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard !Task.isCancelled else { return }
        let result = await Self.scanProject(rootURL: directoryURL, priorityFileURL: nil)
        guard !Task.isCancelled else { return }
        self?.applyIncremental(result: result, directoryURL: directoryURL, rootURL: rootURL)
      }
    }

    private func applyIncremental(result: ScanResult, directoryURL: URL, rootURL: URL) {
      let rootPath = rootURL.standardizedFileURL.path
      guard self.rootURL?.standardizedFileURL.path == rootPath else { return }

      let directoryPath = directoryURL.standardizedFileURL.path
      let directoryPrefix = directoryPath + "/"
      entriesByPath = entriesByPath.filter { path, _ in
        path != directoryPath && !path.hasPrefix(directoryPrefix)
      }
      indexedSwiftFilePaths = indexedSwiftFilePaths.filter { path in
        path != directoryPath && !path.hasPrefix(directoryPrefix)
      }

      for entry in result.entries {
        entriesByPath[entry.fileURL.standardizedFileURL.path] = entry
      }
      for fileURL in result.scannedSwiftFileURLs {
        indexedSwiftFilePaths.insert(fileURL.standardizedFileURL.path)
      }

      rebuildPreviewCandidates()
      updateSnapshot()
      incrementalIndexTasks[directoryPath] = nil
      updateDirectoryWatches(rootURL: rootURL)
      onSnapshotChanged?(snapshot)
    }

    private func updateSnapshot() {
      guard let rootURL else {
        snapshot = nil
        return
      }
      snapshot = Snapshot(
        rootURL: rootURL,
        scannedFileCount: indexedSwiftFilePaths.count,
        previewCount: entriesByPath.values.reduce(0) { $0 + $1.previews.count },
        indexedAt: Date()
      )
    }

    private func rebuildPreviewCandidates() {
      previewCandidates = entriesByPath.values
        .sorted { $0.fileURL.path.localizedStandardCompare($1.fileURL.path) == .orderedAscending }
        .flatMap(\.previews)
    }

    nonisolated private static func resolvedRootURL(projectRootPath: String?, currentFileURL: URL?)
      -> URL?
    {
      if let projectRootPath, !projectRootPath.isEmpty {
        return URL(fileURLWithPath: projectRootPath, isDirectory: true)
      }
      return currentFileURL?.deletingLastPathComponent()
    }

    private struct ScanResult: Sendable {
      let entries: [Entry]
      let scannedFileCount: Int
      let scannedSwiftFileURLs: [URL]
    }

    nonisolated private static func scanProject(rootURL: URL, priorityFileURL: URL?) async
      -> ScanResult
    {
      await Task.detached(priority: .utility) {
        let fileURLs = swiftFileURLs(rootURL: rootURL, priorityFileURL: priorityFileURL)
        let scanner = LumiPreviewFacade.PreviewScanner()
        var entries: [Entry] = []

        for fileURL in fileURLs {
          guard !Task.isCancelled else { break }
          let metadata = metadata(for: fileURL)
          guard metadata.fileSize <= maxFileSize,
            let sourceText = try? String(contentsOf: fileURL, encoding: .utf8),
            sourceText.contains("#Preview")
          else {
            continue
          }

          let previews = scanner.scan(fileURL: fileURL, sourceText: sourceText)
            .strippingSourceText()
          entries.append(
            Entry(
              fileURL: fileURL,
              modifiedAt: metadata.modifiedAt,
              fileSize: metadata.fileSize,
              sourceFingerprint: sourceFingerprint(sourceText),
              previews: previews
            )
          )
        }

        return ScanResult(
          entries: entries, scannedFileCount: fileURLs.count, scannedSwiftFileURLs: fileURLs)
      }.value
    }

    private func updateDirectoryWatches(rootURL: URL) {
      var directoryPaths = Set<String>()
      directoryPaths.insert(rootURL.standardizedFileURL.path)
      for path in indexedSwiftFilePaths {
        let directoryPath = URL(fileURLWithPath: path).deletingLastPathComponent()
          .standardizedFileURL.path
        directoryPaths.insert(directoryPath)
        if directoryPaths.count >= Self.maxWatchedDirectoryCount {
          break
        }
      }

      let currentPaths = Set(directoryWatches.keys)
      for path in currentPaths.subtracting(directoryPaths) {
        stopWatchingDirectory(path: path)
      }
      for path in directoryPaths.subtracting(currentPaths) {
        startWatchingDirectory(URL(fileURLWithPath: path, isDirectory: true))
      }
    }

    private func startWatchingDirectory(_ directoryURL: URL) {
      let path = directoryURL.standardizedFileURL.path
      guard directoryWatches[path] == nil else { return }

      let fileDescriptor = Darwin.open(path, O_EVTONLY)
      guard fileDescriptor >= 0 else { return }

      let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fileDescriptor,
        eventMask: [.write, .delete, .rename, .extend],
        queue: .main
      )
      source.setEventHandler { [weak self] in
        self?.scheduleIncrementalIndex(directoryURL: directoryURL)
      }
      source.setCancelHandler {
        Darwin.close(fileDescriptor)
      }
      directoryWatches[path] = Watch(fileDescriptor: fileDescriptor, source: source)
      source.resume()
    }

    private func stopWatchingDirectory(path: String) {
      guard let watch = directoryWatches.removeValue(forKey: path) else { return }
      watch.source.cancel()
    }

    private func stopDirectoryWatches() {
      for watch in directoryWatches.values {
        watch.source.cancel()
      }
      directoryWatches = [:]
    }

    nonisolated private static func swiftFileURLs(rootURL: URL, priorityFileURL: URL?) -> [URL] {
      let keys: [URLResourceKey] = [
        .isDirectoryKey, .isRegularFileKey, .fileSizeKey, .contentModificationDateKey,
      ]
      guard
        let enumerator = FileManager.default.enumerator(
          at: rootURL,
          includingPropertiesForKeys: keys,
          options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
      else {
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
          (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        else {
          continue
        }
        urls.append(fileURL)
      }

      if let priorityFileURL,
        let index = urls.firstIndex(where: {
          $0.standardizedFileURL.path == priorityFileURL.standardizedFileURL.path
        })
      {
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

    nonisolated private static func metadata(for fileURL: URL) -> (
      modifiedAt: Date?, fileSize: Int64
    ) {
      let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
      return (
        modifiedAt: values?.contentModificationDate,
        fileSize: Int64(values?.fileSize ?? 0)
      )
    }
  }

}
