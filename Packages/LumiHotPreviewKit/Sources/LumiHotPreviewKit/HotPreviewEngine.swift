import Foundation
import LumiPreviewKit

public extension LumiHotPreviewPackage {
    actor HotPreviewSession: LumiPreviewPackage.PreviewSession {
        public nonisolated let id: String

        private var currentDiscovery: LumiPreviewPackage.PreviewDiscovery
        private var currentState: LumiPreviewPackage.PreviewSessionState
        private var currentConfiguration: LumiPreviewPackage.PreviewRenderConfiguration
        private var currentPerformanceMetrics = LumiPreviewPackage.PreviewPerformanceMetrics()
        private var currentDisplayMode: LumiPreviewPackage.PreviewDisplayMode = .image
        private var currentLivePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
        private var currentBuildStrategy: LumiPreviewPackage.BuildStrategy?
        private var currentHostConnection: HotHostConnection?
        private var currentLastHotRenderResponse: HotRenderResponse?
        private var currentLoadedPreviewBodySource: String?
        private var currentLegacySession: (any LumiPreviewPackage.PreviewSession)?

        public var state: LumiPreviewPackage.PreviewSessionState { currentState }
        public var hostingView: (any Sendable)? { nil }
        public var performanceMetrics: LumiPreviewPackage.PreviewPerformanceMetrics { currentPerformanceMetrics }
        public var configuration: LumiPreviewPackage.PreviewRenderConfiguration { currentConfiguration }
        public var displayMode: LumiPreviewPackage.PreviewDisplayMode { currentDisplayMode }
        public var livePreviewInfo: LumiPreviewPackage.LivePreviewInfo { currentLivePreviewInfo }
        public var lastHotRenderResponse: HotRenderResponse? { currentLastHotRenderResponse }

        public var lastRenderResponse: LumiPreviewPackage.RenderResponse? {
            guard let response = currentLastHotRenderResponse else {
                return nil
            }
            return LumiPreviewPackage.RenderResponse(
                success: response.success,
                previewID: response.previewID,
                message: response.message,
                previewImagePNGBase64: response.previewImagePNGBase64,
                diagnostics: response.diagnostics,
                isFallback: response.isFallback,
                livePreviewEnabled: response.livePreviewEnabled,
                liveWindowNumber: response.liveWindowNumber
            )
        }

        public init(
            id: String = UUID().uuidString,
            discovery: LumiPreviewPackage.PreviewDiscovery,
            state: LumiPreviewPackage.PreviewSessionState = .planning,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration = .empty
        ) {
            self.id = id
            self.currentDiscovery = discovery
            self.currentState = state
            self.currentConfiguration = configuration
        }

        public var discovery: LumiPreviewPackage.PreviewDiscovery { currentDiscovery }

        public func updateDiscovery(_ discovery: LumiPreviewPackage.PreviewDiscovery) {
            currentDiscovery = discovery
        }

        func setState(_ state: LumiPreviewPackage.PreviewSessionState) {
            currentState = state
        }

        func setBuildStrategy(_ strategy: LumiPreviewPackage.BuildStrategy) {
            currentBuildStrategy = strategy
        }

        func buildStrategy() -> LumiPreviewPackage.BuildStrategy? {
            currentBuildStrategy
        }

        func setHostConnection(_ connection: HotHostConnection?) {
            currentHostConnection = connection
        }

        func hostConnection() -> HotHostConnection? {
            currentHostConnection
        }

        func setConfiguration(_ configuration: LumiPreviewPackage.PreviewRenderConfiguration) {
            currentConfiguration = configuration
        }

        func setLastHotRenderResponse(_ response: HotRenderResponse) {
            currentLastHotRenderResponse = response
        }

        func setLoadedPreviewBodySource(_ bodySource: String?) {
            currentLoadedPreviewBodySource = bodySource
        }

        func loadedPreviewBodySource() -> String? {
            currentLoadedPreviewBodySource
        }

        func setLegacySession(_ session: (any LumiPreviewPackage.PreviewSession)?) {
            currentLegacySession = session
        }

        func legacySession() -> (any LumiPreviewPackage.PreviewSession)? {
            currentLegacySession
        }

        func setDisplayMode(_ mode: LumiPreviewPackage.PreviewDisplayMode) {
            currentDisplayMode = mode
        }

        func setLivePreviewInfo(_ info: LumiPreviewPackage.LivePreviewInfo) {
            currentLivePreviewInfo = info
        }

        func markLivePreviewAvailable(
            windowNumber: Int? = nil,
            hostProcessID: Int32? = nil,
            forceStopped: Bool = false
        ) {
            let nextState: LumiPreviewPackage.LivePreviewState = forceStopped ? .stopped : .available
            currentLivePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
                state: nextState,
                hostWindowNumber: windowNumber,
                hostProcessID: hostProcessID ?? currentLivePreviewInfo.hostProcessID
            )
        }

        func markLivePreviewRunning(windowNumber: Int? = nil, hostProcessID: Int32? = nil) {
            currentLivePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
                state: .running,
                hostWindowNumber: windowNumber ?? currentLivePreviewInfo.hostWindowNumber,
                hostProcessID: hostProcessID ?? currentLivePreviewInfo.hostProcessID
            )
        }

        func fallbackToImageMode(reason: String) {
            currentDisplayMode = .image
            currentLivePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
                state: .failed,
                unavailableReason: reason
            )
        }

        func recordCompile(duration: TimeInterval, usedCache: Bool) {
            currentPerformanceMetrics.lastCompileDuration = duration
            currentPerformanceMetrics.lastCompileUsedCache = usedCache
        }

        func recordLoad(duration: TimeInterval, usedEntryCache: Bool = false) {
            currentPerformanceMetrics.lastLoadDuration = duration
            currentPerformanceMetrics.lastEntryUsedCache = usedEntryCache
        }

        func recordRefresh(duration: TimeInterval) {
            currentPerformanceMetrics.lastRefreshDuration = duration
        }

        func terminateHost() async {
            await currentHostConnection?.terminate()
            currentHostConnection = nil
            currentLegacySession = nil
        }
    }

    final class HotPreviewEngine: Sendable {
        private enum PreviewEntryVariant: String {
            case moduleImport = "module-import"
            case sourceInclude = "source-include"
        }

        private struct BuiltPreviewEntry {
            let url: URL
            let variant: PreviewEntryVariant
        }

        private struct PrewarmEntryOutcome {
            let usedCachedEntry: Bool
            let builtStrategy: LumiPreviewPackage.BuildStrategy?
        }

        public struct PrewarmEntryResult: Sendable {
            public let discoveryID: String
            public let succeeded: Bool
            public let usedCachedEntry: Bool
            public let errorDescription: String?

            public init(
                discoveryID: String,
                succeeded: Bool,
                usedCachedEntry: Bool = false,
                errorDescription: String?
            ) {
                self.discoveryID = discoveryID
                self.succeeded = succeeded
                self.usedCachedEntry = usedCachedEntry
                self.errorDescription = errorDescription
            }
        }

        private struct ImportAttemptContext {
            let importPlan: ModuleImportPlan
            let fallbackKey: ImportEntryFallbackCache.CacheKey
        }

        private let buildPlanner: LumiPreviewPackage.BuildPlanner
        private let spmCompiler: LumiPreviewPackage.SPMCompiler
        private let xcodeCompiler: LumiPreviewPackage.XcodeCompiler
        private let previewEntryBuilder: LumiPreviewPackage.PreviewEntryBuilder
        private let entryCacheManager: EntryCacheManager
        private let compileCommandCache: CompileCommandCache
        private let incrementalBuildPipeline: IncrementalBuildPipeline
        private let importEntryFallbackCache: ImportEntryFallbackCache
        private let moduleImportEligibilityChecker: ModuleImportEligibilityChecker
        private let moduleImportEligibilityCache: ModuleImportEligibilityCache
        private let syntaxChecker: SyntaxChecker
        private let syntaxPreflightCache = HotSyntaxPreflightCache()
        private let buildCoordinator = HotPreviewBuildCoordinator()
        private let hostProcessManager: HostProcessManager<HotHostConnection>
        private let fallbackEngine: LumiPreviewPackage.LivePreviewEngine?
        private static let previewEntryCacheLimit = 8

        public init(
            hostExecutableURL: URL,
            buildPlanner: LumiPreviewPackage.BuildPlanner = .init(),
            spmCompiler: LumiPreviewPackage.SPMCompiler = .init(),
            xcodeCompiler: LumiPreviewPackage.XcodeCompiler = .init(),
            previewEntryBuilder: LumiPreviewPackage.PreviewEntryBuilder = .init(),
            hotPreviewHostProcess: HotPreviewHostProcess = .init(),
            entryCacheManager: EntryCacheManager = .init(),
            compileCommandCache: CompileCommandCache = .init(),
            incrementalBuildPipeline: IncrementalBuildPipeline = .init(),
            importEntryFallbackCache: ImportEntryFallbackCache = .init(),
            moduleImportEligibilityChecker: ModuleImportEligibilityChecker = .init(),
            moduleImportEligibilityCache: ModuleImportEligibilityCache = .init(),
            syntaxChecker: SyntaxChecker = .init(),
            maximumIdleHosts: Int = 1
        ) {
            self.buildPlanner = buildPlanner
            self.spmCompiler = spmCompiler
            self.xcodeCompiler = xcodeCompiler
            self.previewEntryBuilder = previewEntryBuilder
            self.entryCacheManager = entryCacheManager
            self.compileCommandCache = compileCommandCache
            self.incrementalBuildPipeline = incrementalBuildPipeline
            self.importEntryFallbackCache = importEntryFallbackCache
            self.moduleImportEligibilityChecker = moduleImportEligibilityChecker
            self.moduleImportEligibilityCache = moduleImportEligibilityCache
            self.syntaxChecker = syntaxChecker
            if let legacyHostExecutableURL = LumiPreviewPackage.PreviewHostExecutableResolver.resolve() {
                self.fallbackEngine = LumiPreviewPackage.LivePreviewEngine(
                    hostExecutableURL: legacyHostExecutableURL,
                    buildPlanner: buildPlanner,
                    spmCompiler: spmCompiler,
                    xcodeCompiler: xcodeCompiler,
                    previewEntryBuilder: previewEntryBuilder
                )
            } else {
                self.fallbackEngine = nil
            }
            self.hostProcessManager = HostProcessManager(
                executableURL: hostExecutableURL,
                maximumIdleConnections: maximumIdleHosts,
                launcher: { executableURL in
                    try await hotPreviewHostProcess.launch(executableURL: executableURL)
                },
                isRunning: { connection in
                    await connection.isRunning
                },
                terminate: { connection in
                    await connection.terminate()
                },
                identity: { connection in
                    ObjectIdentifier(connection as AnyObject)
                }
            )
            LumiPreviewPackage.PreviewEntryBuilder.removeExpiredCacheEntries()
        }

        public func warmupHost() async throws {
            try await hostProcessManager.warmup()
        }

        public func shutdownHosts() async {
            await hostProcessManager.shutdown()
        }

        public func discoverPreviews(in fileURL: URL) async -> [LumiPreviewPackage.PreviewDiscovery] {
            guard let sourceText = try? String(contentsOf: fileURL, encoding: .utf8) else {
                return []
            }
            return LumiPreviewPackage.PreviewScanner().scan(fileURL: fileURL, sourceText: sourceText)
        }

        public func startPreview(
            _ discovery: LumiPreviewPackage.PreviewDiscovery,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration = .empty
        ) async throws -> HotPreviewSession {
            let session = HotPreviewSession(discovery: discovery, configuration: configuration)

            do {
                try await syntaxPreflight(discovery)
                try await start(session)
            } catch let error as LumiPreviewPackage.PreviewError {
                if try await startFallbackPreviewIfPossible(
                    discovery: discovery,
                    configuration: configuration,
                    hotSession: session,
                    hotError: error
                ) {
                    return session
                }
                await session.setState(.failed(error))
                throw error
            } catch {
                let wrapped = LumiPreviewPackage.PreviewError.runtimeCrashed(message: error.localizedDescription)
                if try await startFallbackPreviewIfPossible(
                    discovery: discovery,
                    configuration: configuration,
                    hotSession: session,
                    hotError: wrapped
                ) {
                    return session
                }
                await session.setState(.failed(wrapped))
                throw wrapped
            }

            return session
        }

        @discardableResult
        public func prewarmPreviewEntry(
            _ discovery: LumiPreviewPackage.PreviewDiscovery,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration = .empty
        ) async throws -> Bool {
            try await prewarmPreviewEntry(
                discovery,
                configuration: configuration,
                alreadyBuiltStrategies: []
            ).usedCachedEntry
        }

        private func prewarmPreviewEntry(
            _ discovery: LumiPreviewPackage.PreviewDiscovery,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration,
            alreadyBuiltStrategies: Set<LumiPreviewPackage.BuildStrategy>
        ) async throws -> PrewarmEntryOutcome {
            let session = HotPreviewSession(discovery: discovery, configuration: configuration)
            try await syntaxPreflight(discovery)
            let plannedStrategy = try await plannedBuildStrategy(for: session, discovery: discovery)
            if await cachedPreviewEntryURL(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: plannedStrategy
            ) != nil {
                return PrewarmEntryOutcome(usedCachedEntry: true, builtStrategy: nil)
            }

            let effectiveStrategy = await preferredBuildStrategy(
                for: discovery,
                baseStrategy: plannedStrategy
            )
            var rebuiltStrategy: LumiPreviewPackage.BuildStrategy?
            if effectiveStrategy == plannedStrategy,
               alreadyBuiltStrategies.contains(plannedStrategy) {
                await session.setBuildStrategy(plannedStrategy)
            } else {
                try await rebuild(session)
                if effectiveStrategy == plannedStrategy {
                    rebuiltStrategy = plannedStrategy
                }
            }

            let buildStrategy = await session.buildStrategy()
            if await cachedPreviewEntryURL(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy
            ) != nil {
                return PrewarmEntryOutcome(usedCachedEntry: true, builtStrategy: rebuiltStrategy)
            }

            let built = try await buildPreviewEntry(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy
            )
            let builtCacheKey = await entryCacheManager.makeCacheKey(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy,
                entryVariant: built.variant.rawValue
            )
            await entryCacheManager.storeEntryURL(built.url, for: builtCacheKey)
            return PrewarmEntryOutcome(usedCachedEntry: false, builtStrategy: rebuiltStrategy)
        }

        public func prewarmPreviewEntries(
            _ discoveries: [LumiPreviewPackage.PreviewDiscovery],
            configuration: LumiPreviewPackage.PreviewRenderConfiguration = .empty
        ) async -> [PrewarmEntryResult] {
            var results: [PrewarmEntryResult] = []
            var builtStrategies = Set<LumiPreviewPackage.BuildStrategy>()
            for discovery in discoveries {
                guard !Task.isCancelled else { break }
                do {
                    let outcome = try await prewarmPreviewEntry(
                        discovery,
                        configuration: configuration,
                        alreadyBuiltStrategies: builtStrategies
                    )
                    if let builtStrategy = outcome.builtStrategy {
                        builtStrategies.insert(builtStrategy)
                    }
                    results.append(
                        PrewarmEntryResult(
                            discoveryID: discovery.id,
                            succeeded: true,
                            usedCachedEntry: outcome.usedCachedEntry,
                            errorDescription: nil
                        )
                    )
                } catch {
                    results.append(
                        PrewarmEntryResult(
                            discoveryID: discovery.id,
                            succeeded: false,
                            errorDescription: error.localizedDescription
                        )
                    )
                }
            }
            return results
        }

        public func refreshPreview(
            _ session: HotPreviewSession,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration? = nil
        ) async throws {
            if let configuration {
                await session.setConfiguration(configuration)
            }

            if let legacySession = await session.legacySession() {
                try await refreshFallbackPreview(session, legacySession: legacySession)
                return
            }

            do {
                let refreshStart = Date()
                try await syntaxPreflight(await session.discovery)
                try await rebuild(session)
                let connection = try await runningHostConnection(for: session)
                let response = try await loadPreviewEntry(for: session, using: connection)
                await session.setLastHotRenderResponse(response)
                if response.livePreviewEnabled {
                    await session.markLivePreviewAvailable(
                        windowNumber: response.liveWindowNumber,
                        hostProcessID: await connection.processID
                    )
                }
                await session.recordRefresh(duration: Date().timeIntervalSince(refreshStart))
                await session.setState(.running)
            } catch let error as LumiPreviewPackage.PreviewError {
                if let legacySession = try await migrateToFallbackIfPossible(session, hotError: error) {
                    try await refreshFallbackPreview(session, legacySession: legacySession)
                    return
                }
                await session.setState(.failed(error))
                throw error
            } catch {
                let wrapped = LumiPreviewPackage.PreviewError.runtimeCrashed(message: error.localizedDescription)
                if let legacySession = try await migrateToFallbackIfPossible(session, hotError: wrapped) {
                    try await refreshFallbackPreview(session, legacySession: legacySession)
                    return
                }
                await session.setState(.failed(wrapped))
                throw wrapped
            }
        }

        public func stopPreview(_ session: HotPreviewSession) async {
            if let legacySession = await session.legacySession(),
               let fallbackEngine {
                await fallbackEngine.stopPreview(legacySession)
                await session.setLegacySession(nil)
            }
            if let connection = await session.hostConnection() {
                await hostProcessManager.release(connection)
                await session.setHostConnection(nil)
            }
            await session.setState(.stopped)
        }

        public func capturePreviewFrame(_ session: HotPreviewSession) async throws -> HotRenderResponse {
            if let legacySession = await session.legacySession(),
               let fallbackEngine {
                let response = try await fallbackEngine.capturePreviewFrame(legacySession)
                await syncHotSession(session, from: legacySession)
                let hotResponse = HotRenderResponse(response)
                await session.setLastHotRenderResponse(hotResponse)
                return hotResponse
            }
            guard let connection = await session.hostConnection() else {
                throw LumiPreviewPackage.PreviewError.runtimeCrashed(message: "No active hot preview session.")
            }
            let response = try await connection.requestCaptureFrame()
            await session.setLastHotRenderResponse(response)
            return response
        }

        public func startLivePreview(_ session: HotPreviewSession) async throws {
            if let legacySession = await session.legacySession(),
               let fallbackEngine {
                try await fallbackEngine.startLivePreview(legacySession)
                await syncHotSession(session, from: legacySession)
                return
            }
            guard let connection = await session.hostConnection() else {
                throw LumiPreviewPackage.PreviewError.runtimeCrashed(message: "No active hot preview session.")
            }
            let response = try await connection.requestStartLivePreview()
            await session.setLivePreviewInfo(
                LumiPreviewPackage.LivePreviewInfo(
                    state: .running,
                    hostWindowNumber: response.liveWindowNumber,
                    hostProcessID: await connection.processID
                )
            )
            await session.setDisplayMode(.live)
            await session.setLastHotRenderResponse(response)
        }

        public func updateLiveFrame(
            _ session: HotPreviewSession,
            x: Double,
            y: Double,
            width: Double,
            height: Double,
            scale: Double = 1
        ) async throws {
            if let legacySession = await session.legacySession(),
               let fallbackEngine {
                try await fallbackEngine.updateLiveFrame(
                    legacySession,
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    scale: scale
                )
                await syncHotSession(session, from: legacySession)
                return
            }
            guard let connection = await session.hostConnection() else { return }
            _ = try await connection.requestUpdateLiveFrame(x: x, y: y, width: width, height: height, scale: scale)
        }

        public func showLivePreview(_ session: HotPreviewSession) async throws {
            if let legacySession = await session.legacySession(),
               let fallbackEngine {
                try await fallbackEngine.showLivePreview(legacySession)
                await syncHotSession(session, from: legacySession)
                return
            }
            guard let connection = await session.hostConnection() else { return }
            let response = try await connection.requestShowLivePreview()
            await session.markLivePreviewRunning(
                windowNumber: response.liveWindowNumber,
                hostProcessID: await connection.processID
            )
            await session.setLastHotRenderResponse(response)
            await session.setDisplayMode(.live)
        }

        public func hideLivePreview(_ session: HotPreviewSession) async throws {
            if let legacySession = await session.legacySession(),
               let fallbackEngine {
                try await fallbackEngine.hideLivePreview(legacySession)
                await syncHotSession(session, from: legacySession)
                return
            }
            guard let connection = await session.hostConnection() else { return }
            let response = try await connection.requestHideLivePreview()
            await session.markLivePreviewAvailable(
                windowNumber: response.liveWindowNumber,
                hostProcessID: await connection.processID
            )
            await session.setLastHotRenderResponse(response)
            await session.setDisplayMode(.image)
        }

        public func stopLivePreview(_ session: HotPreviewSession) async throws {
            if let legacySession = await session.legacySession(),
               let fallbackEngine {
                try await fallbackEngine.stopLivePreview(legacySession)
                await syncHotSession(session, from: legacySession)
                return
            }
            guard let connection = await session.hostConnection() else { return }
            _ = try await connection.requestStopLivePreview()
            await session.setDisplayMode(.image)
            await session.markLivePreviewAvailable(
                windowNumber: nil,
                hostProcessID: await connection.processID,
                forceStopped: true
            )
        }

        private func syntaxPreflight(_ discovery: LumiPreviewPackage.PreviewDiscovery) async throws {
            let result = await syntaxPreflightCache.result(for: discovery.sourceFileURL) {
                await syntaxChecker.check(fileURL: discovery.sourceFileURL)
            }
            guard case .valid = result else {
                if case .invalid(let issues) = result {
                    let message = issues.map(\.message).joined(separator: "\n")
                    throw LumiPreviewPackage.PreviewError.compilationFailed(message: message)
                }
                return
            }
        }

        private func start(_ session: HotPreviewSession) async throws {
            await session.setState(.planning)
            let discovery = await session.discovery

            guard let strategy = buildPlanner.plan(for: discovery.sourceFileURL) else {
                throw LumiPreviewPackage.PreviewError.targetNotFound(file: discovery.sourceFileURL.path)
            }

            await session.setBuildStrategy(strategy)
            try await build(strategy, session: session)

            await session.setState(.launching)
            let connection = try await hostProcessManager.acquire()
            await session.setHostConnection(connection)

            do {
                let response = try await loadPreviewEntry(for: session, using: connection)
                await session.setLastHotRenderResponse(response)
                if response.livePreviewEnabled {
                    await session.markLivePreviewAvailable(
                        windowNumber: response.liveWindowNumber,
                        hostProcessID: await connection.processID
                    )
                }
                await session.setState(.running)
            } catch {
                await hostProcessManager.discard(connection)
                await session.setHostConnection(nil)
                throw error
            }
        }

        private func rebuild(_ session: HotPreviewSession) async throws {
            let discovery = await session.discovery
            let baseStrategy = try await plannedBuildStrategy(for: session, discovery: discovery)

            let effectiveStrategy = await preferredBuildStrategy(
                for: discovery,
                baseStrategy: baseStrategy
            )
            do {
                try await build(
                    effectiveStrategy,
                    session: session,
                    cachePopulationStrategy: baseStrategy
                )
            } catch where effectiveStrategy != baseStrategy {
                try await build(
                    baseStrategy,
                    session: session,
                    cachePopulationStrategy: baseStrategy
                )
            }
        }

        private func plannedBuildStrategy(
            for session: HotPreviewSession,
            discovery: LumiPreviewPackage.PreviewDiscovery
        ) async throws -> LumiPreviewPackage.BuildStrategy {
            if let existingStrategy = await session.buildStrategy() {
                return existingStrategy
            }
            guard let plannedStrategy = buildPlanner.plan(for: discovery.sourceFileURL) else {
                throw LumiPreviewPackage.PreviewError.targetNotFound(file: discovery.sourceFileURL.path)
            }
            await session.setBuildStrategy(plannedStrategy)
            return plannedStrategy
        }

        private func cachedPreviewEntryURL(
            discovery: LumiPreviewPackage.PreviewDiscovery,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration,
            buildStrategy: LumiPreviewPackage.BuildStrategy?
        ) async -> URL? {
            let preferredVariant = await preferredEntryVariant(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy
            )
            let cacheKey = await entryCacheManager.makeCacheKey(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy,
                entryVariant: preferredVariant.rawValue
            )
            return await entryCacheManager.cachedEntryURL(for: cacheKey)
        }

        private func runningHostConnection(for session: HotPreviewSession) async throws -> HotHostConnection {
            if let existingConnection = await session.hostConnection(),
               await existingConnection.isRunning {
                return existingConnection
            }

            if let existingConnection = await session.hostConnection() {
                await hostProcessManager.discard(existingConnection)
                await session.setHostConnection(nil)
            }
            await session.setState(.launching)
            let connection = try await hostProcessManager.acquire()
            await session.setHostConnection(connection)

            do {
                let response = try await loadPreviewEntry(for: session, using: connection)
                await session.setLastHotRenderResponse(response)
                if response.livePreviewEnabled {
                    await session.markLivePreviewAvailable(
                        windowNumber: response.liveWindowNumber,
                        hostProcessID: await connection.processID
                    )
                }
                return connection
            } catch {
                await hostProcessManager.discard(connection)
                await session.setHostConnection(nil)
                throw error
            }
        }

        private func build(
            _ strategy: LumiPreviewPackage.BuildStrategy,
            session: HotPreviewSession,
            cachePopulationStrategy: LumiPreviewPackage.BuildStrategy? = nil
        ) async throws {
            await session.setState(.compiling(progress: 0))
            let discovery = await session.discovery
            let startedAt = Date()
            let fingerprint = HotBuildFingerprint.make(strategy: strategy, previewFileURL: discovery.sourceFileURL)
            let result = try await buildCoordinator.buildIfNeeded(strategy: strategy, fingerprint: fingerprint) {
                switch strategy {
                case .spm(let packageDirectory, let targetName):
                    _ = try await self.spmCompiler.build(packageDirectory: packageDirectory, targetName: targetName)
                case .xcode(let projectURL, let scheme, let configuration):
                    _ = try await self.xcodeCompiler.build(
                        projectURL: projectURL,
                        scheme: scheme,
                        configuration: configuration
                    )
                case .incremental(let fileURL, let compileCommand):
                    _ = try await self.incrementalBuildPipeline.buildSingleFilePreview(
                        fileURL: fileURL,
                        compileCommand: compileCommand
                    )
                }
            }
            if result == .built {
                await populateCompileCommandCacheIfPossible(
                    for: cachePopulationStrategy ?? strategy,
                    discovery: discovery
                )
            }
            await session.recordCompile(duration: Date().timeIntervalSince(startedAt), usedCache: result != .built)
            await session.setState(.compiling(progress: 1))
        }

        private func loadPreviewEntry(
            for session: HotPreviewSession,
            using connection: HotHostConnection
        ) async throws -> HotRenderResponse {
            let discovery = await session.discovery
            let configuration = await session.configuration
            let buildStrategy = await session.buildStrategy()
            let preferredVariant = await preferredEntryVariant(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy
            )
            let cacheKey = await entryCacheManager.makeCacheKey(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy,
                entryVariant: preferredVariant.rawValue
            )
            let entryURL: URL
            let usedEntryCache: Bool
            if let cached = await entryCacheManager.cachedEntryURL(for: cacheKey) {
                entryURL = cached
                usedEntryCache = true
            } else {
                let built = try await buildPreviewEntry(
                    discovery: discovery,
                    configuration: configuration,
                    buildStrategy: buildStrategy
                )
                let builtCacheKey = await entryCacheManager.makeCacheKey(
                    discovery: discovery,
                    configuration: configuration,
                    buildStrategy: buildStrategy,
                    entryVariant: built.variant.rawValue
                )
                await entryCacheManager.storeEntryURL(built.url, for: builtCacheKey)
                entryURL = built.url
                usedEntryCache = false
            }
            LumiPreviewPackage.PreviewEntryBuilder.removeExpiredCacheEntries(
                keepingNewest: Self.previewEntryCacheLimit
            )

            let loadStart = Date()
            let response: HotRenderResponse
            if await session.livePreviewInfo.state == .running {
                if preferredVariant == .moduleImport,
                   await session.loadedPreviewBodySource() == discovery.bodySource {
                    do {
                        let interposed = try await connection.requestInterposeDylib(
                            at: entryURL,
                            symbolName: LumiPreviewPackage.PreviewEntryBuilder.symbolName
                        )
                        if interposed.success {
                            response = interposed
                        } else {
                            response = try await connection.requestReloadLivePreview(
                                at: entryURL,
                                symbolName: LumiPreviewPackage.PreviewEntryBuilder.symbolName
                            )
                        }
                    } catch {
                        response = try await connection.requestReloadLivePreview(
                            at: entryURL,
                            symbolName: LumiPreviewPackage.PreviewEntryBuilder.symbolName
                        )
                    }
                } else {
                    response = try await connection.requestReloadLivePreview(
                        at: entryURL,
                        symbolName: LumiPreviewPackage.PreviewEntryBuilder.symbolName
                    )
                }
            } else {
                response = try await connection.requestLoadPreviewEntry(
                    at: entryURL,
                    symbolName: LumiPreviewPackage.PreviewEntryBuilder.symbolName
                )
            }
            if response.success {
                await session.setLoadedPreviewBodySource(discovery.bodySource)
            }
            await session.recordLoad(
                duration: Date().timeIntervalSince(loadStart),
                usedEntryCache: usedEntryCache
            )
            return response
        }

        private func buildPreviewEntry(
            discovery: LumiPreviewPackage.PreviewDiscovery,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration,
            buildStrategy: LumiPreviewPackage.BuildStrategy?
        ) async throws -> BuiltPreviewEntry {
            if let buildStrategy,
               canUseModuleImportEntry(buildStrategy: buildStrategy),
               let context = await importAttemptContext(
                    discovery: discovery,
                    configuration: configuration,
                    buildStrategy: buildStrategy
               ) {
                do {
                    let entryURL = try await incrementalBuildPipeline.compilePreviewEntryImportingModule(
                        discovery: discovery,
                        configuration: configuration,
                        buildStrategy: buildStrategy,
                        importPlan: context.importPlan
                    )
                    await importEntryFallbackCache.remove(context.fallbackKey)
                    return BuiltPreviewEntry(url: entryURL, variant: .moduleImport)
                } catch {
                    await importEntryFallbackCache.recordFailure(for: context.fallbackKey)
                    // Fall back to the source-including builder when module import
                    // cannot compile due to access control or missing module context.
                }
            }

            if let buildStrategy {
                do {
                    return BuiltPreviewEntry(
                        url: try await incrementalBuildPipeline.compilePreviewEntryIncludingCurrentSource(
                            discovery: discovery,
                            configuration: configuration,
                            buildStrategy: buildStrategy
                        ),
                        variant: .sourceInclude
                    )
                } catch {
                    // Fall through to the legacy source-including builder as the
                    // last fallback if the current-file-only compilation fails.
                }
            }

            return BuiltPreviewEntry(
                url: try await previewEntryBuilder.buildEntry(
                    for: discovery,
                    configuration: configuration,
                    buildStrategy: buildStrategy
                ),
                variant: .sourceInclude
            )
        }

        private func startFallbackPreviewIfPossible(
            discovery: LumiPreviewPackage.PreviewDiscovery,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration,
            hotSession: HotPreviewSession,
            hotError: LumiPreviewPackage.PreviewError
        ) async throws -> Bool {
            guard let fallbackEngine else {
                return false
            }

            let legacySession = try await fallbackEngine.startPreview(
                discovery,
                configuration: configuration
            )
            await hotSession.setLegacySession(legacySession)
            await syncHotSession(hotSession, from: legacySession, fallbackReason: hotError.localizedDescription)
            return true
        }

        private func migrateToFallbackIfPossible(
            _ hotSession: HotPreviewSession,
            hotError: LumiPreviewPackage.PreviewError
        ) async throws -> (any LumiPreviewPackage.PreviewSession)? {
            guard let fallbackEngine else {
                return nil
            }

            if let legacySession = await hotSession.legacySession() {
                await syncHotSession(hotSession, from: legacySession, fallbackReason: hotError.localizedDescription)
                return legacySession
            }

            let discovery = await hotSession.discovery
            let configuration = await hotSession.configuration
            let legacySession = try await fallbackEngine.startPreview(
                discovery,
                configuration: configuration
            )
            if let connection = await hotSession.hostConnection() {
                await hostProcessManager.discard(connection)
                await hotSession.setHostConnection(nil)
            }
            await hotSession.setLegacySession(legacySession)
            await syncHotSession(hotSession, from: legacySession, fallbackReason: hotError.localizedDescription)
            return legacySession
        }

        private func refreshFallbackPreview(
            _ hotSession: HotPreviewSession,
            legacySession: any LumiPreviewPackage.PreviewSession
        ) async throws {
            guard let fallbackEngine else { return }
            try await fallbackEngine.refreshPreview(legacySession)
            await syncHotSession(hotSession, from: legacySession)
        }

        private func syncHotSession(
            _ hotSession: HotPreviewSession,
            from legacySession: any LumiPreviewPackage.PreviewSession,
            fallbackReason: String? = nil
        ) async {
            await hotSession.setState(await legacySession.state)
            await hotSession.setConfiguration(await legacySession.configuration)
            await hotSession.setDisplayMode(await legacySession.displayMode)
            await hotSession.setLivePreviewInfo(await legacySession.livePreviewInfo)
            if let response = await legacySession.lastRenderResponse {
                await hotSession.setLastHotRenderResponse(HotRenderResponse(response))
            }
            if let fallbackReason {
                var info = await hotSession.livePreviewInfo
                if info.state == .failed && (info.unavailableReason?.isEmpty ?? true) {
                    info.unavailableReason = fallbackReason
                    await hotSession.setLivePreviewInfo(info)
                }
            }
        }

        private func preferredBuildStrategy(
            for discovery: LumiPreviewPackage.PreviewDiscovery,
            baseStrategy: LumiPreviewPackage.BuildStrategy
        ) async -> LumiPreviewPackage.BuildStrategy {
            guard case .xcode = baseStrategy else {
                return baseStrategy
            }

            let key = await compileCommandCache.makeCacheKey(
                for: discovery.sourceFileURL,
                buildStrategy: baseStrategy
            )
            guard let compileCommand = await compileCommandCache.command(for: key) else {
                return baseStrategy
            }

            return .incremental(
                fileURL: discovery.sourceFileURL,
                compileCommand: compileCommand
            )
        }

        private func populateCompileCommandCacheIfPossible(
            for buildStrategy: LumiPreviewPackage.BuildStrategy,
            discovery: LumiPreviewPackage.PreviewDiscovery
        ) async {
            guard case .xcode = buildStrategy else {
                return
            }
            guard let buildLog = try? await incrementalBuildPipeline.captureBuildLog(for: buildStrategy) else {
                return
            }
            guard !buildLog.isEmpty else {
                return
            }

            let commands = incrementalBuildPipeline.extractCommands(
                from: buildLog,
                fileURLs: [discovery.sourceFileURL]
            )
            guard !commands.isEmpty else {
                return
            }
            await compileCommandCache.store(commands: commands, for: buildStrategy)
        }

        private func canUseModuleImportEntry(
            buildStrategy: LumiPreviewPackage.BuildStrategy
        ) -> Bool {
            switch buildStrategy {
            case .spm, .xcode:
                return true
            case .incremental:
                return false
            }
        }

        private func preferredEntryVariant(
            discovery: LumiPreviewPackage.PreviewDiscovery,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration,
            buildStrategy: LumiPreviewPackage.BuildStrategy?
        ) async -> PreviewEntryVariant {
            guard let buildStrategy,
                  canUseModuleImportEntry(buildStrategy: buildStrategy) else {
                return .sourceInclude
            }

            guard await importAttemptContext(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy
            ) != nil else {
                return .sourceInclude
            }
            return .moduleImport
        }

        private func importAttemptContext(
            discovery: LumiPreviewPackage.PreviewDiscovery,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration,
            buildStrategy: LumiPreviewPackage.BuildStrategy
        ) async -> ImportAttemptContext? {
            let eligibilityKey = await moduleImportEligibilityCache.makeCacheKey(
                discovery: discovery
            )
            let isEligible: Bool
            if let cached = await moduleImportEligibilityCache.value(for: eligibilityKey) {
                isEligible = cached
            } else {
                let computed = moduleImportEligibilityChecker.shouldUseModuleImport(
                    discovery: discovery
                )
                await moduleImportEligibilityCache.store(computed, for: eligibilityKey)
                isEligible = computed
            }

            guard isEligible else {
                return nil
            }

            guard let importPlan = try? await incrementalBuildPipeline.resolveModuleImportPlan(
                buildStrategy: buildStrategy
            ) else {
                return nil
            }

            guard importPlan.hasUsableModuleArtifact else {
                return nil
            }

            let fallbackKey = await importEntryFallbackCache.makeCacheKey(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy,
                moduleArtifactFingerprint: moduleArtifactFingerprint(from: importPlan)
            )
            let hasRecordedFallback = await importEntryFallbackCache.contains(fallbackKey)
            guard !hasRecordedFallback else {
                return nil
            }

            return ImportAttemptContext(
                importPlan: importPlan,
                fallbackKey: fallbackKey
            )
        }

        private func moduleArtifactFingerprint(
            from importPlan: ModuleImportPlan
        ) -> String? {
            guard let artifactPath = importPlan.moduleArtifactPath else {
                return nil
            }

            let url = URL(fileURLWithPath: artifactPath)
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modifiedAt = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
            let fileSize = values?.fileSize ?? 0
            return "\(artifactPath)|\(modifiedAt)|\(fileSize)"
        }
    }
}

private actor HotPreviewBuildCoordinator {
    enum Result {
        case built
        case reused
        case joined
    }

    private struct InFlightKey: Hashable {
        let strategy: LumiPreviewPackage.BuildStrategy
        let fingerprint: String
    }

    private var fingerprints: [LumiPreviewPackage.BuildStrategy: String] = [:]
    private var inFlightBuilds: [InFlightKey: Task<Void, Error>] = [:]

    func buildIfNeeded(
        strategy: LumiPreviewPackage.BuildStrategy,
        fingerprint: String?,
        operation: @escaping @Sendable () async throws -> Void
    ) async throws -> Result {
        guard let fingerprint else {
            try await operation()
            return .built
        }

        if fingerprints[strategy] == fingerprint {
            return .reused
        }

        let key = InFlightKey(strategy: strategy, fingerprint: fingerprint)
        if let build = inFlightBuilds[key] {
            try await build.value
            fingerprints[strategy] = fingerprint
            return .joined
        }

        let build = Task {
            try await operation()
        }
        inFlightBuilds[key] = build

        do {
            try await build.value
        } catch {
            inFlightBuilds[key] = nil
            throw error
        }

        inFlightBuilds[key] = nil
        fingerprints[strategy] = fingerprint
        return .built
    }
}

private actor HotSyntaxPreflightCache {
    private struct CacheKey: Hashable {
        let path: String
        let modifiedAt: TimeInterval
        let fileSize: Int
    }

    private var resultsByPath: [String: (key: CacheKey, result: LumiHotPreviewPackage.SyntaxCheckResult)] = [:]
    private let maximumCount = 64

    func result(
        for fileURL: URL,
        check: @Sendable () async -> LumiHotPreviewPackage.SyntaxCheckResult
    ) async -> LumiHotPreviewPackage.SyntaxCheckResult {
        guard let key = cacheKey(for: fileURL) else {
            return await check()
        }

        if let cached = resultsByPath[key.path], cached.key == key {
            return cached.result
        }

        let result = await check()
        resultsByPath[key.path] = (key, result)
        trimIfNeeded()
        return result
    }

    private func cacheKey(for fileURL: URL) -> CacheKey? {
        let standardizedURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        guard let values = try? standardizedURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return nil
        }

        return CacheKey(
            path: standardizedURL.path,
            modifiedAt: values.contentModificationDate?.timeIntervalSince1970 ?? 0,
            fileSize: values.fileSize ?? 0
        )
    }

    private func trimIfNeeded() {
        guard resultsByPath.count > maximumCount else { return }
        let overflow = resultsByPath.count - maximumCount
        for path in resultsByPath.keys.sorted().prefix(overflow) {
            resultsByPath.removeValue(forKey: path)
        }
    }
}

private enum HotBuildFingerprint {
    static func make(strategy: LumiPreviewPackage.BuildStrategy, previewFileURL: URL) -> String? {
        let rootURL: URL
        switch strategy {
        case .spm(let packageDirectory, let targetName):
            rootURL = targetDirectory(
                packageDirectory: packageDirectory,
                targetName: targetName,
                previewFileURL: previewFileURL
            )
        case .xcode(let projectURL, _, _):
            rootURL = projectURL.deletingLastPathComponent()
        case .incremental(let fileURL, _):
            rootURL = fileURL.deletingLastPathComponent()
        }

        return fingerprint(forSwiftFilesIn: rootURL)
    }

    private static func targetDirectory(
        packageDirectory: URL,
        targetName: String,
        previewFileURL: URL
    ) -> URL {
        let standardTargetDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(targetName, isDirectory: true)

        if FileManager.default.fileExists(atPath: standardTargetDirectory.path) {
            return standardTargetDirectory
        }

        return previewFileURL.deletingLastPathComponent()
    }

    private static func fingerprint(forSwiftFilesIn directory: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var parts: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            guard let values = try? url.resourceValues(
                forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
            ), values.isRegularFile == true else {
                continue
            }

            let modifiedAt = values.contentModificationDate?.timeIntervalSince1970 ?? 0
            let fileSize = values.fileSize ?? 0
            parts.append("\(url.path)|\(fileSize)|\(modifiedAt)")
        }

        guard !parts.isEmpty else {
            return nil
        }

        return parts.sorted().joined(separator: "\n")
    }
}
