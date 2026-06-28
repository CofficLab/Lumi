import Foundation
import os
import SuperLogKit

/// Xcode Build Context Provider
/// 职责：
/// 1. 生成/管理 buildServer.json
/// 2. 提供文件到 build context 的映射
/// 3. 缓存 build settings
/// 4. 处理 context invalidation
@MainActor
final public class XcodeBuildContextProvider: SuperLog, ObservableObject {

    nonisolated public static let emoji = "🏗️"
    nonisolated public static let verbose = false

    nonisolated private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.buildcontext")

    // MARK: - Published State

    @Published public private(set) var currentWorkspace: XcodeWorkspaceContext?
    @Published public private(set) var activeScheme: XcodeSchemeContext?
    @Published public private(set) var activeConfiguration: String?
    @Published public private(set) var activeDestination: XcodeDestinationContext?
    @Published public var buildContextStatus: BuildContextStatus = .unknown
    @Published public private(set) var resolutionProgress: BuildContextResolutionProgress?

    @Published public private(set) var buildServerJSONPath: String?
    @Published public private(set) var isGeneratingBuildServer: Bool = false
    @Published public private(set) var semanticIndexStatus: XcodeSemanticIndexStatus = .notStarted

    // MARK: - Cache

    /// build settings 缓存: cacheKey → settings
    private var buildSettingsCache: [String: [[String: String]]] = [:]

    /// file path → matching targets cache.
    private var targetMatchCache: [String: [XcodeTargetContext]] = [:]

    /// xcode-build-server 路径缓存
    private var xcodeBuildServerPath: String?

    private var semanticIndexTask: Task<Void, Never>?

    // MARK: - Dependencies

    /// 解析器
    public let resolver: XcodeProjectResolver

    /// Build Server 存储管理器
    public let store: XcodeBuildServerStore

    // MARK: - 状态枚举

    /// Build context 状态
    public enum BuildContextStatus: Sendable, Equatable {
        case unknown
        case resolving
        case available(XcodeBuildServerConfig)
        case unavailable(String)
        case needsResync

        /// 人类可读的状态描述
        public var displayDescription: String {
            switch self {
            case .unknown:
                return "Unknown"
            case .resolving:
                return "Resolving build context..."
            case .available(let config):
                return "Available (scheme: \(config.scheme))"
            case .unavailable(let reason):
                return "Unavailable: \(reason)"
            case .needsResync:
                return "Needs resync"
            }
        }
    }

    public struct XcodeBuildServerConfig: Equatable, Sendable {
        public let buildServerJSONPath: String
        public let workspacePath: String
        public let scheme: String

        public init(buildServerJSONPath: String, workspacePath: String, scheme: String) {
            self.buildServerJSONPath = buildServerJSONPath
            self.workspacePath = workspacePath
            self.scheme = scheme
        }

        public init(from storeConfig: XcodeBuildServerStore.Config) {
            self.buildServerJSONPath = storeConfig.buildServerJSONPath
            self.workspacePath = storeConfig.workspacePath
            self.scheme = storeConfig.scheme
        }
    }

    // MARK: - 初始化

    public init(
        resolver: XcodeProjectResolver = XcodeProjectResolver(),
        store: XcodeBuildServerStore
    ) {
        self.resolver = resolver
        self.store = store
        Task { [weak self] in
            let path = await XcodeBuildServerLocator.locate()
            await MainActor.run {
                self?.xcodeBuildServerPath = path
            }
        }
    }

    // MARK: - 核心方法

    /// 打开/识别一个 Xcode 项目
    public func openProject(at projectURL: URL) async {
        let reportProgress = makeProgressReporter()

        reportProgress(.init(phase: .locatingWorkspace, detail: projectURL.lastPathComponent))

        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            clearResolutionProgress()
            buildContextStatus = .unavailable("Project path does not exist: \(projectURL.path)")
            return
        }

        let workspaceURL: URL?
        if projectURL.pathExtension == "xcodeproj" || projectURL.pathExtension == "xcworkspace" {
            workspaceURL = projectURL
        } else {
            workspaceURL = await XcodeProjectBackgroundQuery.findWorkspace(in: projectURL.path)
        }
        guard let workspaceURL else {
            clearResolutionProgress()
            buildContextStatus = .unavailable("No .xcodeproj / .xcworkspace found")
            return
        }

        buildContextStatus = .resolving
        reportProgress(.init(phase: .discoveringSchemes, detail: workspaceURL.lastPathComponent))

        let storeDirectory = store.ensureDirectory(forWorkspace: workspaceURL.path)
        let inputFingerprints = await ProjectInputFingerprint.compute(
            workspaceURL: workspaceURL,
            schemeName: nil
        )
        if let cachedWorkspace = ProjectGraphCache.load(
            from: storeDirectory,
            expectedHash: inputFingerprints.pbxprojHash
        ) {
            applyWorkspaceContext(cachedWorkspace)
            if let bestScheme = Self.selectBestScheme(
                schemes: cachedWorkspace.schemes,
                projectName: cachedWorkspace.name,
                targets: cachedWorkspace.projects.flatMap { $0.targets.map(\.name) }
            ) {
                reportProgress(.init(phase: .selectingScheme, detail: bestScheme.name))
                await setActiveScheme(bestScheme, reportProgress: reportProgress)
            }
            return
        }

        let progressHandler = reportProgress
        let fastSchemeNames = await Task.detached(priority: .userInitiated) {
            XcodeSchemeDiscovery.discoverSchemeNames(at: workspaceURL)
        }.value

        reportProgress(.init(phase: .parsingProjectMembership, detail: workspaceURL.lastPathComponent))
        let targetSourceFiles = await Task.detached(priority: .userInitiated) {
            XcodeProjectResolver.resolveTargetSourceFiles(
                projectLikeURL: workspaceURL,
                onScanProgress: { path in
                    progressHandler(.init(phase: .parsingProjectMembership, currentItem: URL(fileURLWithPath: path).lastPathComponent))
                }
            )
        }.value

        var selectedSchemeName: String?
        if !fastSchemeNames.isEmpty {
            let placeholder = XcodeProjectResolver.makePlaceholderWorkspaceContext(
                workspaceURL: workspaceURL,
                schemeNames: fastSchemeNames,
                targetSourceFiles: targetSourceFiles
            )
            applyWorkspaceContext(placeholder)
            if let bestScheme = Self.selectBestScheme(
                schemes: placeholder.schemes,
                projectName: placeholder.name,
                targets: []
            ) {
                selectedSchemeName = bestScheme.name
                reportProgress(.init(phase: .selectingScheme, detail: bestScheme.name))
                await setActiveScheme(bestScheme, reportProgress: reportProgress)
            }
        }

        guard let workspaceContext = await resolver.resolve(workspaceURL: workspaceURL, onProgress: reportProgress) else {
            if fastSchemeNames.isEmpty {
                clearResolutionProgress()
                buildContextStatus = .unavailable("Unable to parse project")
            }
            return
        }

        applyWorkspaceContext(workspaceContext)
        _ = ProjectGraphCache.save(
            workspaceContext,
            pbxprojHash: inputFingerprints.pbxprojHash,
            to: storeDirectory
        )

        let schemeToActivate: XcodeSchemeContext? = {
            if let selectedSchemeName,
               let match = workspaceContext.schemes.first(where: { $0.name == selectedSchemeName }) {
                return match
            }
            return Self.selectBestScheme(
                schemes: workspaceContext.schemes,
                projectName: workspaceContext.name,
                targets: workspaceContext.projects.flatMap { $0.targets.map(\.name) }
            )
        }()

        guard let schemeToActivate else {
            clearResolutionProgress()
            return
        }

        if activeScheme?.name == schemeToActivate.name,
           case .available = buildContextStatus {
            let resolvedScheme = Self.resolvedSchemeSelection(
                schemeToActivate,
                fallbackDestination: activeDestination ?? currentWorkspace?.activeDestination ?? Self.defaultDestination()
            )
            activeScheme = resolvedScheme
            activeConfiguration = resolvedScheme.activeConfiguration
            activeDestination = resolvedScheme.activeDestination
            currentWorkspace?.activeScheme = resolvedScheme
            currentWorkspace?.activeDestination = resolvedScheme.activeDestination
            clearResolutionProgress()
        } else {
            reportProgress(.init(phase: .selectingScheme, detail: schemeToActivate.name))
            await setActiveScheme(schemeToActivate, reportProgress: reportProgress)
        }
    }

    private func makeProgressReporter() -> (@Sendable (BuildContextResolutionProgress.Update) -> Void) {
        { [weak self] update in
            Task { @MainActor in
                self?.applyResolutionProgressUpdate(update)
            }
        }
    }

    private func applyResolutionProgressUpdate(_ update: BuildContextResolutionProgress.Update) {
        guard case .resolving = buildContextStatus else {
            if update.phase == .indexingCompileDatabase {
                resolutionProgress = BuildContextResolutionProgress(updating: resolutionProgress, with: update)
            }
            return
        }
        resolutionProgress = BuildContextResolutionProgress(
            updating: resolutionProgress,
            with: update
        )
    }

    private func clearResolutionProgress() {
        resolutionProgress = nil
    }

    private func applyWorkspaceContext(_ workspaceContext: XcodeWorkspaceContext) {
        currentWorkspace = workspaceContext
        targetMatchCache.removeAll()
        if currentWorkspace?.activeDestination == nil {
            currentWorkspace?.activeDestination = Self.defaultDestination()
        }
        activeDestination = currentWorkspace?.activeDestination
    }

    /// 设置 active scheme
    public func setActiveScheme(_ scheme: XcodeSchemeContext) async {
        await setActiveScheme(scheme, reportProgress: nil)
    }

    private func setActiveScheme(
        _ scheme: XcodeSchemeContext,
        reportProgress: (@Sendable (BuildContextResolutionProgress.Update) -> Void)?
    ) async {
        guard let workspace = currentWorkspace else { return }
        let resolvedScheme = Self.resolvedSchemeSelection(
            scheme,
            fallbackDestination: activeDestination ?? currentWorkspace?.activeDestination ?? Self.defaultDestination()
        )

        if Self.verbose { Self.logger.info("\(Self.t)切换 Scheme: \(resolvedScheme.name, privacy: .public)") }

        activeScheme = resolvedScheme
        activeConfiguration = resolvedScheme.activeConfiguration
        activeDestination = resolvedScheme.activeDestination
        currentWorkspace?.activeScheme = resolvedScheme
        currentWorkspace?.activeDestination = resolvedScheme.activeDestination

        // 清除旧缓存
        buildSettingsCache.removeAll()

        // 重新生成 buildServer.json
        await generateBuildServerJSON(
            workspaceURL: workspace.path,
            scheme: resolvedScheme.name,
            reportProgress: reportProgress
        )
    }

    /// 设置 active configuration
    public func setActiveConfiguration(_ configurationName: String) async {
        guard var scheme = activeScheme else { return }
        scheme = Self.resolvedSchemeConfiguration(scheme, configuration: configurationName)
        activeScheme = scheme
        activeConfiguration = configurationName
        currentWorkspace?.activeScheme = scheme

        // 清除缓存
        buildSettingsCache.removeAll()

        // 重新生成
        if let workspace = currentWorkspace {
            await generateBuildServerJSON(
                workspaceURL: workspace.path,
                scheme: scheme.name,
                reportProgress: nil
            )
        }
    }

    // MARK: - buildServer.json 管理

    /// 生成 buildServer.json
    public func generateBuildServerJSON(workspaceURL: URL, scheme: String) async {
        await generateBuildServerJSON(workspaceURL: workspaceURL, scheme: scheme, reportProgress: nil)
    }

    private func generateBuildServerJSON(
        workspaceURL: URL,
        scheme: String,
        reportProgress: (@Sendable (BuildContextResolutionProgress.Update) -> Void)?
    ) async {
        guard let serverPath = xcodeBuildServerPath else {
            clearResolutionProgress()
            buildContextStatus = .unavailable("xcode-build-server not installed, please run: brew install xcode-build-server")
            return
        }

        // Reuse an existing buildServer.json for the same scheme instead of regenerating it.
        //
        // `xcode-build-server config` rewrites the file on every launch, bumping its modification
        // date. `isCompileDatabaseFresh` compares `.compile` against that date, so a rewrite makes a
        // perfectly good compile database look stale and forces a re-index. Because the project is
        // already built, that re-index is *incremental* and its xcactivitylog only contains the few
        // recompiled targets — so `xcode-build-server parse` shrinks a complete `.compile` down to a
        // partial one, and unrelated files start reporting spurious "No such module" errors.
        if Self.canReuseBuildServerConfig(store.load(forWorkspace: workspaceURL.path), requestedScheme: scheme) {
            let existing = store.load(forWorkspace: workspaceURL.path)!
            buildServerJSONPath = existing.buildServerJSONPath
            buildContextStatus = .available(XcodeBuildServerConfig(from: existing))
            clearResolutionProgress()
            scheduleSemanticIndexing(workspaceURL: workspaceURL)
            if Self.verbose { Self.logger.info("\(Self.t)复用已有 buildServer.json（scheme 未变）: \(existing.buildServerJSONPath, privacy: .public)") }
            return
        }

        reportProgress?(.init(phase: .generatingBuildServer, detail: scheme))
        isGeneratingBuildServer = true

        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let workspaceArg = isProject ? "-project" : "-workspace"

        if Self.verbose { Self.logger.info("\(Self.t)生成 buildServer.json: \(serverPath) config \(workspaceArg) \(workspaceURL.path) -scheme \(scheme)") }

        // 生成到该项目专属的插件存储目录
        let outputDirectory = store.ensureDirectory(forWorkspace: workspaceURL.path)
        let success = await runCommand(
            path: serverPath,
            args: ["config", workspaceArg, workspaceURL.path, "-scheme", scheme],
            workingDirectory: outputDirectory
        )

        isGeneratingBuildServer = false

        let config = success ? store.load(forWorkspace: workspaceURL.path) : nil
        buildContextStatus = Self.buildServerGenerationStatus(success: success, config: config)
        if case .available = buildContextStatus {
            clearResolutionProgress()
            scheduleSemanticIndexing(workspaceURL: workspaceURL)
        } else if case .unavailable = buildContextStatus {
            clearResolutionProgress()
            semanticIndexStatus = .notStarted
        }
        if let config {
            buildServerJSONPath = config.buildServerJSONPath
            if Self.verbose { Self.logger.info("\(Self.t)buildServer.json 已生成: \(config.buildServerJSONPath, privacy: .public)") }
        }
    }

    public func warmSemanticIndex(workspaceURL: URL) {
        scheduleSemanticIndexing(workspaceURL: workspaceURL, priority: .preload)
    }

    private func scheduleSemanticIndexing(
        workspaceURL: URL,
        priority: SemanticIndexJobPriority = .activeWorkspace
    ) {
        if priority == .preload, SemanticIndexJobController.shared.hasActiveWorkspaceJob {
            return
        }
        semanticIndexTask?.cancel()
        semanticIndexTask = Task { [weak self] in
            guard let self else { return }
            let (_, generation) = SemanticIndexJobController.shared.beginJob(priority: priority)
            let result = await SemanticIndexJobController.shared.run(
                generation: generation,
                priority: priority
            ) {
                await self.executeSemanticIndexing(workspaceURL: workspaceURL)
            }
            if result.wasCancelled { return }
            if let failureReason = result.failureReason {
                self.semanticIndexStatus = .failed(failureReason)
            }
        }
    }

    private func scheduleSemanticIndexing(workspaceURL: URL) {
        scheduleSemanticIndexing(workspaceURL: workspaceURL, priority: .activeWorkspace)
    }

    private func executeSemanticIndexing(workspaceURL: URL) async -> SemanticIndexJobResult {
        guard !Task.isCancelled else { return SemanticIndexJobResult(wasCancelled: true) }
        if xcodeBuildServerPath == nil {
            xcodeBuildServerPath = await XcodeBuildServerLocator.locate()
        }
        guard let serverPath = xcodeBuildServerPath else {
            return SemanticIndexJobResult(failureReason: "xcode-build-server not installed")
        }
        xcodeBuildServerPath = serverPath

        let storeDirectory = store.ensureDirectory(forWorkspace: workspaceURL.path)
        guard let metadata = store.loadMetadata(forWorkspace: workspaceURL.path) else {
            return SemanticIndexJobResult(failureReason: "buildServer.json is missing")
        }

        let scheme = activeScheme?.name ?? metadata.scheme
        let configuration = activeConfiguration ?? activeScheme?.activeConfiguration ?? "Debug"
        let destinationQuery = activeDestination?.destinationQuery
            ?? activeScheme?.activeDestination?.destinationQuery
            ?? Self.defaultDestination().destinationQuery
        let inputs = await ProjectInputFingerprint.compute(workspaceURL: workspaceURL, schemeName: scheme)
        let toolchain = ProjectInputFingerprint.currentToolchain(
            xcodeBuildServerVersion: XcodeBuildServerLocator.detectedVersion(at: serverPath)
        )

        let compileURL = URL(fileURLWithPath: metadata.compileDatabasePath)
        let manifest = store.loadManifest(forWorkspace: workspaceURL.path)

        if store.loadManifest(forWorkspace: workspaceURL.path)?.indexingInProgress == true {
            store.clearInterruptedIndexingFlag(forWorkspace: workspaceURL.path)
        }

        if await CompileDatabaseValidator.isValidForOpen(
            manifest: manifest,
            compileDatabaseURL: compileURL,
            scheme: scheme,
            configuration: configuration,
            destination: destinationQuery,
            inputs: inputs,
            toolchain: toolchain
        ) {
            semanticIndexStatus = .ready
            _ = store.publishCompileDatabaseForBSP(forWorkspace: workspaceURL.path)
            SemanticIndexMetrics.recordCacheHit(
                workspacePath: workspaceURL.path,
                entryCount: manifest?.compileDatabase?.entryCount
            )
            return SemanticIndexJobResult()
        }

        SemanticIndexMetrics.recordCacheMiss(
            workspacePath: workspaceURL.path,
            reason: IndexManifestValidation.invalidationReason(
                manifest: manifest,
                compileDatabaseURL: compileURL,
                scheme: scheme,
                configuration: configuration,
                destination: destinationQuery,
                inputs: inputs,
                toolchain: toolchain
            ).map { String(describing: $0) } ?? "unknown"
        )

        semanticIndexStatus = .indexing
        resolutionProgress = BuildContextResolutionProgress(phase: .indexingCompileDatabase)
        store.markIndexingInProgress(
            forWorkspace: workspaceURL.path,
            scheme: scheme,
            configuration: configuration,
            destination: destinationQuery,
            inputs: inputs,
            toolchain: toolchain
        )

        let derivedDataDirectory = store.derivedDataDirectory(forWorkspace: workspaceURL.path)
        try? FileManager.default.createDirectory(
            at: derivedDataDirectory,
            withIntermediateDirectories: true
        )

        let request = XcodeSemanticIndexRunner.Request(
            workspaceURL: workspaceURL,
            scheme: scheme,
            configuration: configuration,
            destinationQuery: destinationQuery,
            storeDirectory: storeDirectory,
            derivedDataDirectory: derivedDataDirectory,
            xcodeBuildServerPath: serverPath,
            buildRoot: metadata.buildRoot
        )

        guard !Task.isCancelled else { return SemanticIndexJobResult(wasCancelled: true) }

        guard SemanticIndexResourceManager.acquireXcodebuildSlot(priority: .activeWorkspace) else {
            return SemanticIndexJobResult(failureReason: "Another semantic index build is already running")
        }
        defer { SemanticIndexResourceManager.releaseXcodebuildSlot() }

        let startedAt = Date()
        SemanticIndexResourceManager.markWorkspaceAccessed(workspaceURL.path)
        _ = await SemanticIndexResourceManager.enforceDiskQuotaAsync(in: store.pluginDirectoryURL)

        let rebuildStrategy = SemanticIndexRebuildPolicy.strategy(
            manifest: manifest,
            inputs: inputs,
            scheme: scheme,
            configuration: configuration,
            destination: destinationQuery
        )

        let failureReason: String?
        switch rebuildStrategy {
        case .skip:
            failureReason = nil
        case .parseFromDerivedDataOnly:
            let parsed = await XcodeSemanticIndexRunner.syncCompileDatabaseFromDerivedData(request)
            failureReason = parsed ? nil : "Unable to parse compile database from derived data"
        case .cleanBuildAndParse, .incrementalBuildAndMerge:
            failureReason = await XcodeSemanticIndexRunner.buildAndParseCompileDatabase(request)
        }

        if let failureReason {
            store.clearInterruptedIndexingFlag(forWorkspace: workspaceURL.path)
            return SemanticIndexJobResult(failureReason: failureReason)
        }

        if let buildRoot = XcodeSemanticIndexRunner.discoverBuildRoot(in: derivedDataDirectory) {
            let indexStorePath = XcodeBuildServerStore
                .defaultIndexStorePath(forDerivedDataDirectory: derivedDataDirectory)
                .path
            _ = store.syncParsedCompileDatabaseSettings(
                forWorkspace: workspaceURL.path,
                buildRoot: buildRoot,
                indexStorePath: indexStorePath
            )
        } else {
            _ = store.publishCompileDatabaseForBSP(forWorkspace: workspaceURL.path)
        }
        _ = await store.finalizeManifestAfterIndexing(
            forWorkspace: workspaceURL.path,
            scheme: scheme,
            configuration: configuration,
            destination: destinationQuery,
            inputs: inputs,
            toolchain: toolchain,
            compileDatabaseURL: compileURL
        )
        clearResolutionProgress()
        let entryCount = (await CompileDatabaseValidator.makeCompileDatabaseInfo(at: compileURL, scheme: scheme))?.entryCount ?? 0
        SemanticIndexMetrics.recordIndexCompleted(
            workspacePath: workspaceURL.path,
            duration: Date().timeIntervalSince(startedAt),
            entryCount: entryCount
        )
        semanticIndexStatus = .ready
        return SemanticIndexJobResult()
    }

    /// Whether an existing `buildServer.json` can be reused as-is for the requested scheme.
    ///
    /// Reusing it (instead of re-running `xcode-build-server config`) keeps the file's modification
    /// date stable, which prevents the freshness check from spuriously invalidating a complete
    /// `.compile` and triggering an incremental re-index that would corrupt it.
    static func canReuseBuildServerConfig(
        _ config: XcodeBuildServerStore.Config?,
        requestedScheme: String
    ) -> Bool {
        guard let config, !config.scheme.isEmpty else { return false }
        return config.scheme == requestedScheme
    }

    public static func buildServerGenerationStatus(
        success: Bool,
        config: XcodeBuildServerStore.Config?
    ) -> BuildContextStatus {
        if success, let config {
            return .available(XcodeBuildServerConfig(from: config))
        } else if success {
            return .unavailable("Generated buildServer.json was missing or invalid")
        } else {
            return .unavailable("Failed to generate buildServer.json")
        }
    }

    // MARK: - 文件归属查询

    /// 查询文件属于哪个 target
    public func findTargetForFile(fileURL: URL) -> XcodeTargetContext? {
        resolvePreferredTarget(for: fileURL)
    }

    /// 查询文件属于哪些 target
    public func findTargetsForFile(fileURL: URL) -> [XcodeTargetContext] {
        guard let workspace = currentWorkspace else { return [] }

        let filePath = XcodeProjectResolver.normalizedMembershipPath(for: fileURL)
        if let cached = targetMatchCache[filePath] {
            return cached
        }
        var matches: [XcodeTargetContext] = []
        for project in workspace.projects {
            for target in project.targets {
                if XcodeProjectResolver.targetMembershipContains(fileURL: fileURL, sourceFiles: target.sourceFiles) {
                    matches.append(target)
                }
            }
        }
        targetMatchCache[filePath] = matches
        return matches
    }

    public func resolvePreferredTarget(for fileURL: URL) -> XcodeTargetContext? {
        let matches = findTargetsForFile(fileURL: fileURL)
        guard !matches.isEmpty else { return nil }
        if matches.count == 1 {
            return matches[0]
        }
        return preferredTargets(for: matches).first
    }

    public func targetsCompatibleWithActiveScheme(for fileURL: URL) -> [XcodeTargetContext] {
        let matches = findTargetsForFile(fileURL: fileURL)
        guard let activeScheme else { return matches }
        return matches.filter { activeScheme.buildableTargets.contains($0.name) || $0.name == activeScheme.name }
    }

    /// 获取文件的编译上下文（供 LSP 使用）
    public func buildContextForFile(fileURL: URL) async -> XcodeFileBuildContext? {
        guard let workspace = currentWorkspace,
              let scheme = activeScheme else { return nil }
        let configuration = activeConfiguration ?? scheme.activeConfiguration
        let matchedTargets = preferredTargets(for: findTargetsForFile(fileURL: fileURL)).map(\.name)
        let destination = activeDestination?.destinationQuery ?? scheme.activeDestination?.destinationQuery

        // 先从缓存查找
        let cacheKey = Self.buildSettingsCacheKey(
            workspaceID: workspace.id,
            scheme: scheme.name,
            configuration: configuration,
            destination: destination
        )
        if let cached = buildSettingsCache[cacheKey], !cached.isEmpty {
            let selectedSettings = selectBuildSettings(from: cached, preferredTargetNames: matchedTargets) ?? cached.first!
            updateActiveDestination(using: selectedSettings)
            return XcodeFileBuildContext(
                fileURL: fileURL,
                settings: selectedSettings,
                scheme: scheme.name,
                workspacePath: workspace.rootURL.path
            )
        }

        // 实时获取
        let workspaceURL = workspace.path.pathExtension == "xcworkspace" ? workspace.path : nil
        let projectURL = workspace.path.pathExtension == "xcodeproj" ? workspace.path : workspace.projects.first?.path
        let settings = await resolver.fetchBuildSettings(
            workspaceURL: workspaceURL,
            projectURL: projectURL,
            scheme: scheme.name,
            configuration: configuration,
            destination: destination
        )

        guard let settings = settings, !settings.isEmpty else { return nil }

        buildSettingsCache[cacheKey] = settings
        let selectedSettings = selectBuildSettings(from: settings, preferredTargetNames: matchedTargets) ?? settings.first!
        updateActiveDestination(using: selectedSettings)

        return XcodeFileBuildContext(
            fileURL: fileURL,
            settings: selectedSettings,
            scheme: scheme.name,
            workspacePath: workspace.rootURL.path
        )
    }

    // MARK: - User Build Coordination

    /// Pauses semantic indexing without discarding the active workspace context.
    public func pauseSemanticIndexingForUserBuild() {
        semanticIndexTask?.cancel()
        semanticIndexTask = nil
        SemanticIndexJobController.shared.cancelCurrentJob()
    }

    // MARK: - Context Invalidation

    /// 使所有缓存失效
    public func invalidateAllContexts() {
        semanticIndexTask?.cancel()
        semanticIndexTask = nil
        SemanticIndexJobController.shared.cancelCurrentJob()
        buildSettingsCache.removeAll()
        targetMatchCache.removeAll()
        clearResolutionProgress()
        semanticIndexStatus = .notStarted
        buildContextStatus = .needsResync
        currentWorkspace = nil
        activeScheme = nil
        activeConfiguration = nil
        activeDestination = nil
        buildServerJSONPath = nil
        if Self.verbose { Self.logger.info("\(Self.t)所有 build context 已失效") }
    }

    /// 使特定 scheme 的缓存失效
    public func invalidateContext(for schemeName: String) {
        invalidateScheme(schemeName)
    }

    public func invalidateScheme(_ schemeName: String) {
        buildSettingsCache = Self.invalidatedBuildSettingsCache(
            buildSettingsCache,
            removingScheme: schemeName
        )
        if activeScheme?.name == schemeName {
            activeScheme = nil
            activeConfiguration = nil
        }
        if Self.verbose { Self.logger.info("\(Self.t)Scheme '\(schemeName, privacy: .public)' 的 build context 已失效") }
    }

    public func invalidateProjectGraph(forWorkspace workspacePath: String) {
        let storeDirectory = store.ensureDirectory(forWorkspace: workspacePath)
        try? FileManager.default.removeItem(at: ProjectGraphCache.url(in: storeDirectory))
        currentWorkspace = nil
        targetMatchCache.removeAll()
    }

    public func invalidateCompileDatabase(forWorkspace workspacePath: String) {
        let compileURL = store.compileDatabaseURL(forWorkspace: workspacePath)
        try? FileManager.default.removeItem(at: compileURL)
        if var manifest = store.loadManifest(forWorkspace: workspacePath) {
            manifest.compileDatabase = nil
            manifest.indexingInProgress = false
            store.saveManifest(manifest, forWorkspace: workspacePath)
        }
        semanticIndexStatus = .notStarted
    }

    // MARK: - Scheme 智能选择

    /// 选择最佳 scheme
    public static func selectBestScheme(
        schemes: [XcodeSchemeContext],
        projectName: String,
        targets: [String]
    ) -> XcodeSchemeContext? {
        guard !schemes.isEmpty else { return nil }

        // 1. 优先：与项目同名的 scheme
        if let match = schemes.first(where: { $0.name == projectName }) {
            if Self.verbose { Self.logger.info("\(Self.t)自动选择 Scheme（与项目同名）: \(match.name, privacy: .public)") }
            return match
        }

        // 2. 其次：与某个 target 同名的 scheme（排除 Package scheme）
        let nonPackageTargets = targets.filter { !$0.hasSuffix("-Package") }
        for target in nonPackageTargets {
            if let match = schemes.first(where: { $0.name == target }) {
                if Self.verbose { Self.logger.info("\(Self.t)自动选择 Scheme（与 target 同名）: \(match.name, privacy: .public)") }
                return match
            }
        }

        // 3. 排除已知的依赖包 scheme
        let dependencySuffixes = ["-Package", "-Testing", "Testing"]
        let dependencyPrefixes = ["SwiftTreeSitter", "Semaphore"]
        let isKnownDependency: (String) -> Bool = { name in
            dependencySuffixes.contains(where: { name.hasSuffix($0) }) ||
            dependencyPrefixes.contains(where: { name.hasPrefix($0) }) ||
            name == "EditorLanguages" || name == "TextStory"
        }

        if let match = schemes.first(where: { !isKnownDependency($0.name) }) {
            if Self.verbose { Self.logger.info("\(Self.t)自动选择 Scheme（排除依赖包后）: \(match.name, privacy: .public)") }
            return match
        }

        // 4. 兜底
        let fallback = schemes[0]
        if Self.verbose { Self.logger.info("\(Self.t)自动选择 Scheme（兜底）: \(fallback.name, privacy: .public)") }
        return fallback
    }

    public static func defaultDestination() -> XcodeDestinationContext {
        XcodeDestinationContext.macOSDefault()
    }

    public static func resolvedSchemeSelection(
        _ scheme: XcodeSchemeContext,
        fallbackDestination: XcodeDestinationContext
    ) -> XcodeSchemeContext {
        var resolvedScheme = scheme
        if resolvedScheme.activeConfiguration.isEmpty {
            resolvedScheme.activeConfiguration = resolvedScheme.defaultConfiguration ?? "Debug"
        }
        if resolvedScheme.activeDestination == nil {
            resolvedScheme.activeDestination = fallbackDestination
        }
        return resolvedScheme
    }

    public static func resolvedSchemeConfiguration(
        _ scheme: XcodeSchemeContext,
        configuration: String
    ) -> XcodeSchemeContext {
        var resolved = scheme
        resolved.activeConfiguration = configuration
        return resolved
    }

    public static func buildSettingsCacheKey(
        workspaceID: String,
        scheme: String,
        configuration: String,
        destination: String?
    ) -> String {
        "\(workspaceID)|\(scheme)|\(configuration)|\(destination ?? "default")"
    }

    public static func cacheKey(_ key: String, matchesScheme scheme: String) -> Bool {
        let components = key.split(separator: "|", omittingEmptySubsequences: false)
        guard components.count >= 4 else { return false }
        return String(components[1]) == scheme
    }

    public static func invalidatedBuildSettingsCache(
        _ cache: [String: [[String: String]]],
        removingScheme scheme: String
    ) -> [String: [[String: String]]] {
        cache.filter { key, _ in
            !cacheKey(key, matchesScheme: scheme)
        }
    }

    // MARK: - 工具方法

    /// 执行命令
    private func runCommand(path: String, args: [String], workingDirectory: URL? = nil) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: path)
            process.arguments = args
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            if let workingDirectory {
                process.currentDirectoryURL = workingDirectory
            }

            process.terminationHandler = { _ in
                continuation.resume(returning: process.terminationStatus == 0)
            }

            do {
                try process.run()
            } catch {
                if Self.verbose {
                                    Self.logger.error("\(Self.t)命令执行失败: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume(returning: false)
            }
        }
    }


    private func updateActiveDestination(using settings: [String: String]) {
        let derived = deriveDestination(from: settings)
        guard activeDestination != derived else { return }
        activeDestination = derived
        currentWorkspace?.activeDestination = derived
        if var scheme = activeScheme {
            scheme.activeDestination = derived
            activeScheme = scheme
            currentWorkspace?.activeScheme = scheme
        }
    }

    private func deriveDestination(from settings: [String: String]) -> XcodeDestinationContext {
        let platformName = settings["PLATFORM_NAME"] ?? settings["EFFECTIVE_PLATFORM_NAME"] ?? "macosx"
        let sdkRoot = settings["SDKROOT"] ?? platformName
        let arch = settings["NATIVE_ARCH_64_BIT"] ?? settings["ARCHS"]?.split(separator: " ").first.map(String.init)

        let platform: String
        let name: String
        if sdkRoot.contains("iphoneos") || platformName.contains("iphoneos") {
            platform = "iOS"
            name = arch.map { "Any iPhone Device (\($0))" } ?? "Any iPhone Device"
        } else if sdkRoot.contains("iphonesimulator") || platformName.contains("iphonesimulator") {
            platform = "iOS Simulator"
            name = arch.map { "Any iOS Simulator (\($0))" } ?? "Any iOS Simulator"
        } else if sdkRoot.contains("appletvosimulator") || platformName.contains("appletvsimulator") {
            platform = "tvOS Simulator"
            name = arch.map { "Any tvOS Simulator (\($0))" } ?? "Any tvOS Simulator"
        } else if sdkRoot.contains("appletvos") || platformName.contains("appletvos") {
            platform = "tvOS"
            name = arch.map { "Any Apple TV Device (\($0))" } ?? "Any Apple TV Device"
        } else if sdkRoot.contains("watchsimulator") || platformName.contains("watchsimulator") {
            platform = "watchOS Simulator"
            name = arch.map { "Any watchOS Simulator (\($0))" } ?? "Any watchOS Simulator"
        } else if sdkRoot.contains("watchos") || platformName.contains("watchos") {
            platform = "watchOS"
            name = arch.map { "Any Apple Watch Device (\($0))" } ?? "Any Apple Watch Device"
        } else {
            platform = "macOS"
            name = arch.map { "My Mac (\($0))" } ?? "My Mac"
        }

        return XcodeDestinationContext(
            id: "\(platform)-\(arch ?? "default")",
            platform: platform,
            arch: arch,
            name: name,
            destinationQuery: destinationQuery(forPlatform: platform, arch: arch)
        )
    }

    private func destinationQuery(forPlatform platform: String, arch: String?) -> String {
        let queryPlatform: String
        switch platform {
        case "iOS":
            queryPlatform = "iOS"
        case "iOS Simulator":
            queryPlatform = "iOS Simulator"
        case "tvOS":
            queryPlatform = "tvOS"
        case "tvOS Simulator":
            queryPlatform = "tvOS Simulator"
        case "watchOS":
            queryPlatform = "watchOS"
        case "watchOS Simulator":
            queryPlatform = "watchOS Simulator"
        default:
            queryPlatform = "macOS"
        }
        if let arch, !arch.isEmpty {
            return "platform=\(queryPlatform),arch=\(arch)"
        }
        return "platform=\(queryPlatform)"
    }

    private func selectBuildSettings(
        from settingsList: [[String: String]],
        preferredTargetNames: [String]
    ) -> [String: String]? {
        guard !preferredTargetNames.isEmpty else { return settingsList.first }
        for preferredTargetName in preferredTargetNames {
            if let match = settingsList.first(where: { $0["TARGET_NAME"] == preferredTargetName }) {
                return match
            }
        }
        return settingsList.first
    }

    private func preferredTargets(for matches: [XcodeTargetContext]) -> [XcodeTargetContext] {
        guard matches.count > 1 else { return matches }

        let schemeName = activeScheme?.name
        let buildableTargets = activeScheme?.buildableTargets ?? []
        let buildableOrder = Self.buildableTargetOrder(buildableTargets)

        return matches.sorted { lhs, rhs in
            let lhsPriority = targetPriority(lhs, schemeName: schemeName, buildableOrder: buildableOrder)
            let rhsPriority = targetPriority(rhs, schemeName: schemeName, buildableOrder: buildableOrder)
            if lhsPriority != rhsPriority {
                return lhsPriority > rhsPriority
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func buildableTargetOrder(_ buildableTargets: [String]) -> [String: Int] {
        var orderByTarget: [String: Int] = [:]
        for (index, target) in buildableTargets.enumerated() where orderByTarget[target] == nil {
            orderByTarget[target] = index
        }
        return orderByTarget
    }

    private func targetPriority(
        _ target: XcodeTargetContext,
        schemeName: String?,
        buildableOrder: [String: Int]
    ) -> Int {
        var score = 0
        if target.name == schemeName {
            score += 10_000
        }
        if let order = buildableOrder[target.name] {
            score += 5_000 - order
        }
        score += productTypePriority(target.productType)
        return score
    }

    private func productTypePriority(_ productType: String?) -> Int {
        guard let productType = productType?.lowercased() else { return 0 }
        if productType.contains("application") {
            return 400
        }
        if productType.contains("app-extension") || productType.contains("extension") {
            return 300
        }
        if productType.contains("framework") || productType.contains("library") {
            return 250
        }
        if productType.contains("bundle.unit-test") || productType.contains("ui-testing") || productType.contains("test") {
            return 100
        }
        return 200
    }
}
