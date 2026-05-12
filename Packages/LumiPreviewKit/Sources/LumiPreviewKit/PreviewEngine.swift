import Foundation

/// 预览引擎：LumiPreviewKit 的核心协议。
///
/// 职责：发现源码中的 #Preview → 规划编译 → 启动预览 → 响应文件变化刷新。
public protocol PreviewEngine: AnyObject, Sendable {
    /// 扫描指定文件中的 #Preview 宏，返回可用的预览列表。
    func discoverPreviews(in fileURL: URL) async -> [PreviewDiscovery]

    /// 启动一个预览会话。
    func startPreview(_ discovery: PreviewDiscovery) async throws -> any PreviewSession

    /// 文件变化后刷新预览。
    func refreshPreview(_ session: any PreviewSession) async throws

    /// 停止预览会话。
    func stopPreview(_ session: any PreviewSession) async
}

public final class LivePreviewEngine: PreviewEngine, Sendable {
    private let scanner: PreviewScanner
    private let buildPlanner: BuildPlanner
    private let spmCompiler: SPMCompiler
    private let xcodeCompiler: XcodeCompiler
    private let previewHostProcess: PreviewHostProcess
    private let previewEntryBuilder: PreviewEntryBuilder
    private let hostExecutableURL: URL
    private let buildCoordinator = PreviewBuildCoordinator()

    /// 创建默认预览引擎。
    ///
    /// - Parameters:
    ///   - hostExecutableURL: `LumiPreviewHostApp` 可执行文件路径。
    ///   - scanner: 源码扫描器。
    ///   - buildPlanner: 编译规划器。
    ///   - spmCompiler: SwiftPM 编译器。
    ///   - xcodeCompiler: Xcode 编译器。
    ///   - previewHostProcess: 预览宿主进程管理器。
    ///   - previewEntryBuilder: 动态预览入口构建器。
    public init(
        hostExecutableURL: URL,
        scanner: PreviewScanner = PreviewScanner(),
        buildPlanner: BuildPlanner = BuildPlanner(),
        spmCompiler: SPMCompiler = SPMCompiler(),
        xcodeCompiler: XcodeCompiler = XcodeCompiler(),
        previewHostProcess: PreviewHostProcess = PreviewHostProcess(),
        previewEntryBuilder: PreviewEntryBuilder = PreviewEntryBuilder()
    ) {
        self.hostExecutableURL = hostExecutableURL
        self.scanner = scanner
        self.buildPlanner = buildPlanner
        self.spmCompiler = spmCompiler
        self.xcodeCompiler = xcodeCompiler
        self.previewHostProcess = previewHostProcess
        self.previewEntryBuilder = previewEntryBuilder
        PreviewEntryBuilder.removeExpiredCacheEntries()
    }

    public func discoverPreviews(in fileURL: URL) async -> [PreviewDiscovery] {
        guard let sourceText = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        return scanner.scan(fileURL: fileURL, sourceText: sourceText)
    }

    public func startPreview(_ discovery: PreviewDiscovery) async throws -> any PreviewSession {
        try await startPreview(discovery, configuration: .empty)
    }

    /// 使用指定渲染配置启动一个预览会话。
    public func startPreview(
        _ discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration
    ) async throws -> any PreviewSession {
        let session = LivePreviewSession(discovery: discovery, configuration: configuration)

        do {
            try await start(session)
        } catch let error as PreviewError {
            await session.setState(.failed(error))
        } catch {
            await session.setState(.failed(.runtimeCrashed(message: error.localizedDescription)))
        }

        return session
    }

    /// 使用新的渲染配置刷新预览。
    public func refreshPreview(
        _ session: any PreviewSession,
        configuration: PreviewRenderConfiguration
    ) async throws {
        guard let liveSession = session as? LivePreviewSession else {
            throw PreviewError.unsupportedProjectType(path: "Unsupported PreviewSession implementation.")
        }

        await liveSession.setConfiguration(configuration)
        try await refreshPreview(liveSession)
    }

    public func refreshPreview(_ session: any PreviewSession) async throws {
        guard let liveSession = session as? LivePreviewSession else {
            throw PreviewError.unsupportedProjectType(path: "Unsupported PreviewSession implementation.")
        }

        do {
            let refreshStart = Date()
            try await rebuild(liveSession)
            let connection = try await runningHostConnection(for: liveSession)
            let response = try await loadPreviewEntry(for: liveSession, using: connection)
            await liveSession.setLastRenderResponse(response)
            if response.livePreviewEnabled {
                await liveSession.markLivePreviewAvailable(
                    windowNumber: response.liveWindowNumber,
                    hostProcessID: await connection.processID
                )
            }
            await liveSession.recordRefresh(duration: Date().timeIntervalSince(refreshStart))
            await liveSession.setState(.running)
        } catch let error as PreviewError {
            await liveSession.setState(.failed(error))
            throw error
        } catch {
            let previewError = PreviewError.runtimeCrashed(message: error.localizedDescription)
            await liveSession.setState(.failed(previewError))
            throw previewError
        }
    }

    public func stopPreview(_ session: any PreviewSession) async {
        guard let liveSession = session as? LivePreviewSession else { return }
        await liveSession.terminateHost()
        await liveSession.setState(.stopped)
    }

    // MARK: - Live Preview Control

    /// 请求宿主进程启动 Live 预览窗口。
    public func startLivePreview(_ session: any PreviewSession) async throws {
        guard let liveSession = session as? LivePreviewSession,
              let connection = await liveSession.hostConnection() else {
            throw PreviewError.runtimeCrashed(message: "No active session for live preview.")
        }
        let response = try await connection.requestStartLivePreview()
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Failed to start live preview.")
        }
        await liveSession.setLivePreviewInfo(LivePreviewInfo(
            state: .running,
            hostWindowNumber: response.liveWindowNumber,
            hostProcessID: await connection.processID
        ))
    }

    /// 更新 Live 预览窗口的屏幕坐标和尺寸。
    public func updateLiveFrame(
        _ session: any PreviewSession,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        scale: Double = 1
    ) async throws {
        guard let liveSession = session as? LivePreviewSession,
              let connection = await liveSession.hostConnection() else { return }
        _ = try? await connection.requestUpdateLiveFrame(x: x, y: y, width: width, height: height, scale: scale)
    }

    /// 显示 Live 预览窗口。
    public func showLivePreview(_ session: any PreviewSession) async throws {
        guard let liveSession = session as? LivePreviewSession,
              let connection = await liveSession.hostConnection() else { return }
        _ = try? await connection.requestShowLivePreview()
    }

    /// 隐藏 Live 预览窗口。
    public func hideLivePreview(_ session: any PreviewSession) async throws {
        guard let liveSession = session as? LivePreviewSession,
              let connection = await liveSession.hostConnection() else { return }
        _ = try? await connection.requestHideLivePreview()
    }

    /// 重新加载 Live 预览（加载新 dylib，替换 root view）。
    public func reloadLivePreview(_ session: any PreviewSession, dylibURL: URL) async throws {
        guard let liveSession = session as? LivePreviewSession,
              let connection = await liveSession.hostConnection() else { return }
        let loadStart = Date()
        let response = try await connection.requestReloadLivePreview(
            at: dylibURL,
            symbolName: PreviewEntryBuilder.symbolName
        )
        guard response.success else {
            throw PreviewError.runtimeCrashed(message: response.message ?? "Failed to reload live preview.")
        }
        await liveSession.recordLoad(duration: Date().timeIntervalSince(loadStart))
    }

    /// 停止 Live 预览窗口。
    public func stopLivePreview(_ session: any PreviewSession) async throws {
        guard let liveSession = session as? LivePreviewSession,
              let connection = await liveSession.hostConnection() else { return }
        _ = try? await connection.requestStopLivePreview()
        await liveSession.setLivePreviewInfo(LivePreviewInfo(
            state: .available,
            hostWindowNumber: nil,
            hostProcessID: await connection.processID
        ))
    }

    private func start(_ session: LivePreviewSession) async throws {
        await session.setState(.planning)
        let discovery = await session.discovery

        guard let strategy = buildPlanner.plan(for: discovery.sourceFileURL) else {
            throw PreviewError.targetNotFound(file: discovery.sourceFileURL.path)
        }

        await session.setBuildStrategy(strategy)
        try await build(strategy, session: session)

        await session.setState(.launching)
        let connection = try await previewHostProcess.launch(executableURL: hostExecutableURL)
        await session.setHostConnection(connection)

        do {
            let response = try await loadPreviewEntry(for: session, using: connection)
            await session.setLastRenderResponse(response)
            if response.livePreviewEnabled {
                await session.markLivePreviewAvailable(
                    windowNumber: response.liveWindowNumber,
                    hostProcessID: await connection.processID
                )
            }
            await session.setState(.running)
        } catch {
            await connection.terminate()
            throw error
        }
    }

    private func rebuild(_ session: LivePreviewSession) async throws {
        let discovery = await session.discovery
        let strategy: BuildStrategy
        if let existingStrategy = await session.buildStrategy() {
            strategy = existingStrategy
        } else if let plannedStrategy = buildPlanner.plan(for: discovery.sourceFileURL) {
            strategy = plannedStrategy
            await session.setBuildStrategy(plannedStrategy)
        } else {
            throw PreviewError.targetNotFound(file: discovery.sourceFileURL.path)
        }

        try await build(strategy, session: session)
    }

    private func runningHostConnection(for session: LivePreviewSession) async throws -> HostConnection {
        if let existingConnection = await session.hostConnection(),
           await existingConnection.isRunning {
            return existingConnection
        }

        await session.terminateHost()
        await session.setState(.launching)
        let connection = try await previewHostProcess.launch(executableURL: hostExecutableURL)
        await session.setHostConnection(connection)

        do {
            let response = try await loadPreviewEntry(for: session, using: connection)
            await session.setLastRenderResponse(response)
            if response.livePreviewEnabled {
                await session.markLivePreviewAvailable(
                    windowNumber: response.liveWindowNumber,
                    hostProcessID: await connection.processID
                )
            }
            return connection
        } catch {
            await connection.terminate()
            throw error
        }
    }

    private func build(_ strategy: BuildStrategy, session: LivePreviewSession) async throws {
        await session.setState(.compiling(progress: 0))
        let discovery = await session.discovery
        let startedAt = Date()
        let fingerprint = BuildFingerprint.make(
            strategy: strategy,
            previewFileURL: discovery.sourceFileURL
        )
        let result = try await buildCoordinator.buildIfNeeded(
            strategy: strategy,
            fingerprint: fingerprint
        ) {
            switch strategy {
            case .spm(let packageDirectory, let targetName):
                _ = try await self.spmCompiler.build(packageDirectory: packageDirectory, targetName: targetName)
            case .xcode(let projectURL, let scheme, let configuration):
                _ = try await self.xcodeCompiler.build(
                    projectURL: projectURL,
                    scheme: scheme,
                    configuration: configuration
                )
            case .incremental(let fileURL, _):
                throw PreviewError.unsupportedProjectType(path: fileURL.path)
            }
        }
        await session.recordCompile(
            duration: Date().timeIntervalSince(startedAt),
            usedCache: result != .built
        )
        await session.setState(.compiling(progress: 1))
    }

    private func loadPreviewEntry(
        for session: LivePreviewSession,
        using connection: HostConnection
    ) async throws -> RenderResponse {
        let discovery = await session.discovery
        let entryURL = try await previewEntryBuilder.buildEntry(
            for: discovery,
            configuration: await session.configuration,
            buildStrategy: await session.buildStrategy()
        )

        if await session.livePreviewInfo.state == .running {
            let loadStart = Date()
            let response = try await connection.requestReloadLivePreview(
                at: entryURL,
                symbolName: PreviewEntryBuilder.symbolName
            )
            await session.recordLoad(duration: Date().timeIntervalSince(loadStart))
            return response
        }

        let loadStart = Date()
        let response = try await connection.requestLoadPreviewEntry(
            at: entryURL,
            symbolName: PreviewEntryBuilder.symbolName
        )
        await session.recordLoad(duration: Date().timeIntervalSince(loadStart))
        return response
    }
}

private actor PreviewBuildCoordinator {
    enum Result {
        case built
        case reused
        case joined
    }

    private struct InFlightKey: Hashable {
        let strategy: BuildStrategy
        let fingerprint: String
    }

    private var fingerprints: [BuildStrategy: String] = [:]
    private var inFlightBuilds: [InFlightKey: Task<Void, Error>] = [:]

    func buildIfNeeded(
        strategy: BuildStrategy,
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

private enum BuildFingerprint {
    static func make(strategy: BuildStrategy, previewFileURL: URL) -> String? {
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
