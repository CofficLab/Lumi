import AppKit
import Foundation
import LumiCoreKit
import SuperLogKit
import XcodeKit
import os

private let maxOutputLineCount = 10_000
private let outputFlushIntervalNanoseconds: UInt64 = 100_000_000

/// Orchestrates Build & Run for Xcode and SPM projects.
@MainActor
public final class SwiftBuildRunManager: ObservableObject, SuperLog {
    public static let shared = SwiftBuildRunManager()

    public nonisolated static let emoji = "▶️"
    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.swift.build-run")

    @Published public private(set) var phase: SwiftBuildRunPhase = .idle
    @Published public private(set) var logStages: [SwiftBuildRunStageRecord] = []
    @Published public var selectedLogStage: SwiftBuildRunLogStage = .preflight
    @Published public private(set) var outputText: String = ""
    @Published public private(set) var omittedLineCount: Int = 0
    @Published public private(set) var issues: [SwiftBuildIssue] = []
    @Published public private(set) var lastDuration: TimeInterval = 0
    @Published public private(set) var lastError: String?
    @Published public private(set) var runDisabledReason: String?
    public var onPresentOutput: (() -> Void)?

    private let xcodeRunner = XcodeUserBuildRunner()
    private let spmRunner = SPMUserBuildRunner()
    private let store = EditorSwiftBuildServerStore.makeStore()
    private var cancelRequested = false
    private var activeRunTask: Task<Void, Never>?
    private var stageOutputs: [SwiftBuildRunLogStage: SwiftBuildRunStageOutputState] = [:]
    private var currentLogStage: SwiftBuildRunLogStage = .preflight
    private var outputFlushTask: Task<Void, Never>?

    public var hasAnyStageOutput: Bool {
        logStages.contains { !$0.outputText.isEmpty } || !issues.isEmpty
    }

    public var canRun: Bool {
        guard runDisabledReason == nil else { return false }
        return !phase.isActive
    }

    public var isActive: Bool {
        phase.isActive
    }

    public var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    public var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    public func refreshPreflight(
        provider: XcodeBuildContextProvider?,
        projectPath: String?,
        currentFileURL: URL?,
        fallbackScheme: String? = nil,
        fallbackConfiguration: String? = nil,
        fallbackDestinationQuery: String? = nil
    ) async {
        guard !phase.isActive else { return }
        let result = await SwiftProjectRunPlanner.preflight(
            provider: provider,
            projectPath: projectPath,
            currentFileURL: currentFileURL,
            store: store,
            fallbackScheme: fallbackScheme,
            fallbackConfiguration: fallbackConfiguration,
            fallbackDestinationQuery: fallbackDestinationQuery
        )
        runDisabledReason = result.isReady ? nil : result.disabledReason
    }

    public func run(
        provider: XcodeBuildContextProvider?,
        projectPath: String?,
        currentFileURL: URL?,
        fallbackScheme: String? = nil,
        fallbackConfiguration: String? = nil,
        fallbackDestinationQuery: String? = nil
    ) {
        if phase.isActive {
            cancel()
            return
        }

        onPresentOutput?()
        phase = .preflighting
        activeRunTask?.cancel()
        activeRunTask = Task {
            await performRun(
                provider: provider,
                projectPath: projectPath,
                currentFileURL: currentFileURL,
                fallbackScheme: fallbackScheme,
                fallbackConfiguration: fallbackConfiguration,
                fallbackDestinationQuery: fallbackDestinationQuery
            )
        }
    }

    public func cancel() {
        guard phase.isActive else { return }
        cancelRequested = true
        Task {
            await xcodeRunner.cancel()
            await spmRunner.cancel()
        }
    }

    private func performRun(
        provider: XcodeBuildContextProvider?,
        projectPath: String?,
        currentFileURL: URL?,
        fallbackScheme: String?,
        fallbackConfiguration: String?,
        fallbackDestinationQuery: String?
    ) async {
        phase = .preflighting
        cancelRequested = false
        resetOutput()
        lastError = nil
        let startTime = Date()

        appendOutput(LumiPluginLocalization.string("Checking run configuration…", bundle: .module))

        let preflight = await SwiftProjectRunPlanner.preflight(
            provider: provider,
            projectPath: projectPath,
            currentFileURL: currentFileURL,
            store: store,
            fallbackScheme: fallbackScheme,
            fallbackConfiguration: fallbackConfiguration,
            fallbackDestinationQuery: fallbackDestinationQuery
        )

        guard let context = preflight.context else {
            lastError = preflight.disabledReason
            runDisabledReason = preflight.disabledReason
            failCurrentLogStage()
            phase = .failed
            appendOutput(preflight.disabledReason ?? "Run is unavailable.")
            flushPendingOutputSync()
            return
        }

        appendOutput(LumiPluginLocalization.string("Run configuration is ready.", bundle: .module))
        flushPendingOutputSync()

        runDisabledReason = nil
        BuildJobCoordinator.prepareForUserBuild(provider: provider)

        transitionLogStage(to: .build)
        phase = .building
        var buildResult: SwiftBuildRunResult

        switch context {
        case let .xcode(workspaceURL, scheme, configuration, destinationQuery, derivedDataPath, preferredTargetName):
            let request = XcodeUserBuildRunner.Request(
                workspaceURL: workspaceURL,
                scheme: scheme,
                configuration: configuration,
                destinationQuery: destinationQuery,
                derivedDataDirectory: derivedDataPath,
                workingDirectory: workspaceURL.deletingLastPathComponent()
            )
            buildResult = await xcodeRunner.build(request: request) { [weak self] line in
                Task { @MainActor in
                    self?.appendOutput(line)
                }
            }

            if buildResult.isSuccess, buildResult.productURL == nil {
                let preferredNames = [preferredTargetName, scheme].compactMap { $0 }
                let buildOutput = buildResult.stdout + "\n" + buildResult.stderr
                let productURL = await resolveXcodeProduct(
                    provider: provider,
                    workspaceURL: workspaceURL,
                    scheme: scheme,
                    configuration: configuration,
                    destinationQuery: destinationQuery,
                    derivedDataPath: derivedDataPath,
                    preferredTargetNames: preferredNames,
                    buildOutput: buildOutput
                )
                buildResult = SwiftBuildRunResult(
                    exitCode: buildResult.exitCode,
                    stdout: buildResult.stdout,
                    stderr: buildResult.stderr,
                    issues: buildResult.issues,
                    productURL: productURL,
                    wasCancelled: buildResult.wasCancelled
                )
            }

        case let .spm(packageRoot, executableTarget, configuration):
            let request = SPMUserBuildRunner.Request(
                packageRoot: packageRoot,
                executableTarget: executableTarget,
                configuration: configuration
            )
            buildResult = await spmRunner.build(request: request) { [weak self] line in
                Task { @MainActor in
                    self?.appendOutput(line)
                }
            }
        }

        applyBuildResult(buildResult)
        flushPendingOutputSync()
        lastDuration = Date().timeIntervalSince(startTime)

        if cancelRequested || buildResult.wasCancelled {
            failCurrentLogStage()
            phase = .cancelled
            return
        }

        guard buildResult.isSuccess else {
            lastError = XcodeBuildIssueParser.failureSummary(
                stdout: buildResult.stdout,
                stderr: buildResult.stderr,
                exitCode: buildResult.exitCode
            )
            failCurrentLogStage()
            phase = .failed
            return
        }

        transitionLogStage(to: .launch)
        phase = .launching

        guard let productURL = buildResult.productURL else {
            lastError = "Build succeeded but no runnable product was found."
            appendOutput(lastError!)
            failCurrentLogStage()
            flushPendingOutputSync()
            phase = .failed
            return
        }

        appendOutput("Launching \(productURL.path)")
        flushPendingOutputSync()

        do {
            try await launchProduct(at: productURL, workingDirectory: workingDirectory(for: context))
            appendOutput(
                String(
                    format: LumiPluginLocalization.string("Launched %@", bundle: .module),
                    productURL.lastPathComponent
                )
            )
            completeLogStage(.launch)
            flushPendingOutputSync()
            phase = .succeeded
        } catch {
            lastError = error.localizedDescription
            appendOutput(error.localizedDescription)
            failCurrentLogStage()
            flushPendingOutputSync()
            phase = .failed
        }
    }

    private func resolveXcodeProduct(
        provider: XcodeBuildContextProvider?,
        workspaceURL: URL,
        scheme: String,
        configuration: String,
        destinationQuery: String,
        derivedDataPath: URL,
        preferredTargetNames: [String],
        buildOutput: String
    ) async -> URL? {
        var buildSettings: [[String: String]]?
        if let provider {
            let workspaceContextURL = workspaceURL.pathExtension == "xcworkspace" ? workspaceURL : nil
            let projectURL = workspaceURL.pathExtension == "xcodeproj" ? workspaceURL : nil
            buildSettings = await provider.resolver.fetchBuildSettings(
                workspaceURL: workspaceContextURL,
                projectURL: projectURL,
                scheme: scheme,
                configuration: configuration,
                destination: destinationQuery
            )
        }

        return XcodeBuildProductResolver.resolveXcodeProduct(
            buildSettings: buildSettings,
            derivedDataDirectory: derivedDataPath,
            configuration: configuration,
            preferredTargetNames: preferredTargetNames,
            buildOutput: buildOutput
        )
    }

    private func workingDirectory(for context: SwiftProjectRunContext) -> URL {
        switch context {
        case let .xcode(workspaceURL, _, _, _, _, _):
            return workspaceURL.deletingLastPathComponent()
        case let .spm(packageRoot, _, _):
            return packageRoot
        }
    }

    private func launchProduct(at productURL: URL, workingDirectory: URL) async throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: productURL.path, isDirectory: &isDirectory) else {
            throw NSError(
                domain: "SwiftBuildRunManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Product not found at \(productURL.path)"]
            )
        }

        if isDirectory.boolValue, productURL.pathExtension == "app" {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            configuration.arguments = []

            do {
                _ = try await NSWorkspace.shared.openApplication(at: productURL, configuration: configuration)
                return
            } catch {
                Self.logger.warning("\(Self.t)NSWorkspace launch failed, falling back to /usr/bin/open: \(error.localizedDescription, privacy: .public)")
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-n", productURL.path]
            try process.run()
            return
        }

        let process = Process()
        process.executableURL = productURL
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = nil
        process.standardError = nil
        try process.run()
    }

    private func applyBuildResult(_ result: SwiftBuildRunResult) {
        let parsed = XcodeBuildIssueParser.parse(stdout: result.stdout, stderr: result.stderr)
        if parsed.issues.isEmpty {
            issues = result.issues
        } else {
            issues = parsed.issues
        }
        if lineBufferIsEmptyForCurrentStage() && pendingLinesIsEmptyForCurrentStage() {
            replaceOutputLines(parsed.lines)
        }
    }

    private func lineBufferIsEmptyForCurrentStage() -> Bool {
        stageOutputs[currentLogStage]?.lineBuffer.isEmpty ?? true
    }

    private func pendingLinesIsEmptyForCurrentStage() -> Bool {
        stageOutputs[currentLogStage]?.pendingLines.isEmpty ?? true
    }

    private func resetOutput() {
        outputFlushTask?.cancel()
        outputFlushTask = nil
        stageOutputs = Dictionary(
            uniqueKeysWithValues: SwiftBuildRunLogStage.allCases.map { ($0, SwiftBuildRunStageOutputState()) }
        )
        logStages = SwiftBuildRunLogStage.allCases.map { stage in
            SwiftBuildRunStageRecord(
                stage: stage,
                status: stage == .preflight ? .active : .pending,
                outputText: "",
                omittedLineCount: 0
            )
        }
        currentLogStage = .preflight
        selectedLogStage = .preflight
        outputText = ""
        omittedLineCount = 0
        issues = []
    }

    func selectLogStage(_ stage: SwiftBuildRunLogStage) {
        selectedLogStage = stage
        let state = stageOutputs[stage, default: SwiftBuildRunStageOutputState()]
        outputText = state.outputText
        omittedLineCount = state.omittedLineCount
    }

    func localizedTitle(for stage: SwiftBuildRunLogStage) -> String {
        switch stage {
        case .preflight:
            return LumiPluginLocalization.string("Stage: Prepare", bundle: .module)
        case .build:
            return LumiPluginLocalization.string("Stage: Build", bundle: .module)
        case .launch:
            return LumiPluginLocalization.string("Stage: Launch", bundle: .module)
        }
    }

    func fullLogTextForCopy() -> String {
        var sections: [String] = []

        if let lastError, !lastError.isEmpty {
            sections.append(lastError)
        }

        if !issues.isEmpty {
            let issueText = issues.map { issue in
                var line = issue.message
                if let file = issue.file, let lineNumber = issue.line {
                    line = "\(file):\(lineNumber): \(issue.message)"
                }
                switch issue.severity {
                case .error:
                    return "error: \(line)"
                case .warning:
                    return "warning: \(line)"
                }
            }.joined(separator: "\n")
            sections.append(issueText)
        }

        for record in logStages where !record.outputText.isEmpty {
            sections.append("=== \(localizedTitle(for: record.stage)) ===\n\(record.outputText)")
        }

        return sections.joined(separator: "\n\n")
    }

    private func activateLogStage(_ stage: SwiftBuildRunLogStage) {
        currentLogStage = stage
        selectedLogStage = stage
        updateStageRecord(stage) { record in
            record.status = .active
        }
        let state = stageOutputs[stage, default: SwiftBuildRunStageOutputState()]
        outputText = state.outputText
        omittedLineCount = state.omittedLineCount
    }

    private func completeLogStage(_ stage: SwiftBuildRunLogStage, status: SwiftBuildRunStageStatus = .completed) {
        flushPendingOutputSync()
        updateStageRecord(stage) { record in
            if record.status == .active || record.status == .pending {
                record.status = status
            }
        }
    }

    private func failCurrentLogStage() {
        flushPendingOutputSync()
        updateStageRecord(currentLogStage) { record in
            if record.status == .active {
                record.status = .failed
            }
        }
    }

    private func transitionLogStage(to stage: SwiftBuildRunLogStage) {
        flushPendingOutputSync()
        if currentLogStage != stage {
            completeLogStage(currentLogStage)
        }
        activateLogStage(stage)
    }

    private func syncStageRecord(_ stage: SwiftBuildRunLogStage, from state: SwiftBuildRunStageOutputState) {
        guard let index = logStages.firstIndex(where: { $0.stage == stage }) else { return }
        logStages[index].outputText = state.outputText
        logStages[index].omittedLineCount = state.omittedLineCount
        if selectedLogStage == stage {
            outputText = state.outputText
            omittedLineCount = state.omittedLineCount
        }
    }

    private func updateStageRecord(_ stage: SwiftBuildRunLogStage, mutate: (inout SwiftBuildRunStageRecord) -> Void) {
        guard let index = logStages.firstIndex(where: { $0.stage == stage }) else { return }
        mutate(&logStages[index])
    }

    private func currentStageState() -> SwiftBuildRunStageOutputState {
        stageOutputs[currentLogStage, default: SwiftBuildRunStageOutputState()]
    }

    private func setCurrentStageState(_ state: SwiftBuildRunStageOutputState) {
        stageOutputs[currentLogStage] = state
        syncStageRecord(currentLogStage, from: state)
    }

    private func appendOutput(_ line: String) {
        guard !line.isEmpty else { return }
        var state = currentStageState()
        state.pendingLines.append(line)
        setCurrentStageState(state)
        scheduleOutputFlush()
    }

    private func replaceOutputLines(_ lines: [String]) {
        outputFlushTask?.cancel()
        outputFlushTask = nil
        var state = currentStageState()
        state.pendingLines = []
        state.lineBuffer = lines.filter { !$0.isEmpty }
        state.omittedLineCount = 0
        trimLineBufferIfNeeded(for: &state)
        state.outputText = state.lineBuffer.joined(separator: "\n")
        setCurrentStageState(state)
    }

    private func scheduleOutputFlush() {
        guard outputFlushTask == nil else { return }
        outputFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: outputFlushIntervalNanoseconds)
            self?.flushPendingOutput()
            self?.outputFlushTask = nil
        }
    }

    private func flushPendingOutputSync() {
        outputFlushTask?.cancel()
        outputFlushTask = nil
        flushPendingOutput()
    }

    private func flushPendingOutput() {
        var state = currentStageState()
        guard !state.pendingLines.isEmpty else { return }

        let batch = state.pendingLines
        state.pendingLines = []

        let didTrimBefore = state.lineBuffer.count > maxOutputLineCount
        state.lineBuffer.append(contentsOf: batch)
        let didTrim = trimLineBufferIfNeeded(for: &state)

        if didTrim || didTrimBefore || state.outputText.isEmpty {
            state.outputText = state.lineBuffer.joined(separator: "\n")
        } else {
            let chunk = batch.joined(separator: "\n")
            state.outputText += (state.outputText.isEmpty ? "" : "\n") + chunk
        }

        setCurrentStageState(state)
    }

    @discardableResult
    private func trimLineBufferIfNeeded(for state: inout SwiftBuildRunStageOutputState) -> Bool {
        guard state.lineBuffer.count > maxOutputLineCount else { return false }
        let overflow = state.lineBuffer.count - maxOutputLineCount
        state.lineBuffer.removeFirst(overflow)
        state.omittedLineCount += overflow
        return true
    }
}
