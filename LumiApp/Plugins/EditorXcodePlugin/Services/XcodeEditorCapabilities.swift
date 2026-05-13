import Foundation
import XcodeKit
import MagicKit
import os

@MainActor
final class XcodeProjectContextCapabilityAdapter: SuperEditorProjectContextCapability, SuperLog {
    nonisolated static let emoji = "📁"

    let id = "XcodeProjectContextCapability"
    private let bridge: XcodeProjectContextBridge
    private var projectCapabilityCache: [String: Bool] = [:]

    init(bridge: XcodeProjectContextBridge = .shared) {
        self.bridge = bridge
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)初始化完成")
        }
    }

    func canHandleProject(at path: String?) -> Bool {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(self.t)canHandleProject: 路径为空 -> false")
            }
            return false
        }
        if let cachedState = bridge.cachedState, cachedState.projectPath == path {
            projectCapabilityCache[path] = cachedState.isXcodeProject
            return cachedState.isXcodeProject
        }
        if let cached = projectCapabilityCache[path] {
            return cached
        }
        let canHandle = XcodeProjectResolver.isXcodeProjectRoot(URL(filePath: path))
        projectCapabilityCache[path] = canHandle
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)canHandleProject: \(path) -> \(canHandle)")
        }
        return canHandle
    }

    func projectOpened(at path: String) async {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)projectOpened 开始: \(path)")
        }
        await bridge.projectOpened(at: path)
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)projectOpened 完成: \(path)")
        }
    }

    func projectClosed() {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)projectClosed")
        }
        bridge.projectClosed()
    }

    func resyncProjectContext() async {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)resyncProjectContext 开始")
        }
        await bridge.resyncBuildContext()
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)resyncProjectContext 完成")
        }
    }

    func makeEditorContextSnapshot(currentFileURL: URL?) -> EditorProjectContextSnapshot? {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)makeEditorContextSnapshot，currentFile: \(currentFileURL?.path ?? "nil")")
        }
        guard let snapshot = bridge.makeEditorContextSnapshot(currentFileURL: currentFileURL) else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(self.t)snapshot 为空")
            }
            return nil
        }
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)snapshot 创建成功，workspace: \(snapshot.workspaceName), scheme: \(snapshot.activeScheme ?? "nil")")
        }
        return EditorProjectContextSnapshot(
            projectPath: snapshot.projectPath,
            workspaceName: snapshot.workspaceName,
            workspacePath: snapshot.workspacePath,
            activeScheme: snapshot.activeScheme,
            activeSchemeBuildableTargets: snapshot.activeSchemeBuildableTargets,
            activeConfiguration: snapshot.activeConfiguration,
            activeDestination: snapshot.activeDestination,
            contextStatus: status(from: snapshot.buildContextStatus),
            isStructuredProject: snapshot.isXcodeProject,
            schemes: snapshot.schemes,
            configurations: snapshot.configurations,
            currentFilePath: snapshot.currentFilePath,
            currentFilePrimaryTarget: snapshot.currentFileTarget,
            currentFileMatchedTargets: snapshot.currentFileMatchedTargets,
            currentFileIsInTarget: snapshot.currentFileIsInTarget
        )
    }

    func updateLatestEditorSnapshot(_ snapshot: EditorProjectContextSnapshot?) {
        guard let snapshot else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(self.t)updateLatestEditorSnapshot: nil")
            }
            bridge.updateLatestEditorSnapshot(nil)
            return
        }
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)updateLatestEditorSnapshot: workspace=\(snapshot.workspaceName), file=\(snapshot.currentFilePath ?? "nil")")
        }
        bridge.updateLatestEditorSnapshot(
            XcodeEditorContextSnapshot(
                projectPath: snapshot.projectPath,
                workspaceName: snapshot.workspaceName,
                workspacePath: snapshot.workspacePath,
                activeScheme: snapshot.activeScheme,
                activeSchemeBuildableTargets: snapshot.activeSchemeBuildableTargets,
                activeConfiguration: snapshot.activeConfiguration,
                activeDestination: snapshot.activeDestination,
                buildContextStatus: snapshot.contextStatus.displayDescription,
                isXcodeProject: snapshot.isStructuredProject,
                schemes: snapshot.schemes,
                configurations: snapshot.configurations,
                currentFilePath: snapshot.currentFilePath,
                currentFileTarget: snapshot.currentFilePrimaryTarget,
                currentFileMatchedTargets: snapshot.currentFileMatchedTargets,
                currentFileIsInTarget: snapshot.currentFileIsInTarget
            )
        )
    }

    private func status(from description: String) -> EditorProjectContextStatus {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)状态映射: \(description)")
        }
        if description.contains("Needs resync") {
            return .needsResync
        }
        if description.contains("Resolving build context...") {
            return .resolving
        }
        if description.contains(": ") && !description.contains("Available") {
            let prefix = "Unavailable" + ": "
            if description.hasPrefix(prefix) {
                return .unavailable(String(description.dropFirst(prefix.count)))
            }
            return .unavailable(description)
        }
        if description.contains("Available") {
            return .available(description)
        }
        if description == "Not Initialized"
            || description == "Unknown" {
            return .unknown
        }
        return .available(description)
    }
}

@MainActor
final class XcodeLanguageIntegrationCapabilityAdapter: SuperEditorLanguageIntegrationCapability, SuperLog {
    nonisolated static let emoji = "🧩"

    let id = "XcodeLanguageIntegrationCapability"
    private let bridge: XcodeProjectContextBridge
    private var projectSupportCache: [String: Bool] = [:]

    init(bridge: XcodeProjectContextBridge = .shared) {
        self.bridge = bridge
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)初始化完成")
        }
    }

    func supports(languageId: String, projectPath: String?) -> Bool {
        guard languageId == "swift" || languageId == "sourcekit" else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(self.t)supports: languageId=\(languageId) 不支持")
            }
            return false
        }
        guard let projectPath, !projectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(self.t)supports: projectPath 为空")
            }
            return false
        }
        if let cachedState = bridge.cachedState, cachedState.projectPath == projectPath {
            projectSupportCache[projectPath] = cachedState.isXcodeProject
            return cachedState.isXcodeProject
        }
        if let cached = projectSupportCache[projectPath] {
            return cached
        }
        let supported = XcodeProjectResolver.isXcodeProjectRoot(URL(filePath: projectPath))
        projectSupportCache[projectPath] = supported
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)supports: language=\(languageId), project=\(projectPath) -> \(supported)")
        }
        return supported
    }

    func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]? {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)workspaceFolders 请求，language=\(languageId), project=\(projectPath)")
        }
        guard supports(languageId: languageId, projectPath: projectPath),
              let folders = bridge.makeWorkspaceFolders(),
              !folders.isEmpty else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(self.t)workspaceFolders 为空")
            }
            return nil
        }
        let result: [EditorWorkspaceFolder] = folders.compactMap { (item: [String: String]) -> EditorWorkspaceFolder? in
            guard let uri = item["uri"], let name = item["name"] else { return nil }
            return EditorWorkspaceFolder(uri: uri, name: name)
        }
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)workspaceFolders 返回 \(result.count) 项")
        }
        return result
    }

    func initializationOptions(for languageId: String, projectPath: String) -> [String: String]? {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)initializationOptions 请求，language=\(languageId), project=\(projectPath)")
        }
        guard supports(languageId: languageId, projectPath: projectPath),
              let options = bridge.makeInitializationOptions(),
              !options.isEmpty else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(self.t)initializationOptions 为空")
            }
            return nil
        }
        let result = options.reduce(into: [String: String]()) { partial, entry in
            partial[entry.key] = String(describing: entry.value)
        }
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)initializationOptions 返回 key 数: \(result.count)")
        }
        return result
    }
}

@MainActor
final class XcodeSemanticCapabilityAdapter: SuperEditorSemanticCapability, SuperLog {
    nonisolated static let emoji = "🧠"

    let id = "XcodeSemanticCapability"

    func canHandle(uri: String?) -> Bool {
        guard let uri, !uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(self.t)canHandle: uri 为空 -> false")
            }
            return false
        }
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)canHandle: \(uri) -> true")
        }
        return true
    }

    func inspectCurrentFileContext(uri: String?) -> EditorSemanticAvailabilityReport {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)inspectCurrentFileContext: \(uri ?? "nil")")
        }
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(uri: uri, contextProvider: XcodeProjectContextBridge.shared)
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)inspectCurrentFileContext 完成，reasons: \(report.reasons.count)")
        }
        return EditorSemanticAvailabilityReport(
            reasons: report.reasons.map { reason in
                EditorSemanticAvailabilityReason(
                    id: reason.id,
                    severity: mapSeverity(reason.severity),
                    title: reason.title,
                    message: reason.message
                )
            }
        )
    }

    func preflightMessage(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> String? {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)preflightMessage operation=\(operation), symbol=\(symbolName ?? "nil"), strength=\(String(describing: strength))")
        }
        let message = XcodeSemanticAvailability.preflightMessage(
            uri: uri,
            operation: operation,
            symbolName: symbolName,
            strength: strength == .hard ? .hard : .soft,
            contextProvider: XcodeProjectContextBridge.shared
        )
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)preflightMessage 结果: \(message ?? "nil")")
        }
        return message
    }

    func preflightError(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> EditorLanguageFeatureError? {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)preflightError operation=\(operation), symbol=\(symbolName ?? "nil"), strength=\(String(describing: strength))")
        }
        guard let error = XcodeSemanticAvailability.preflightError(
            uri: uri,
            operation: operation,
            symbolName: symbolName,
            strength: strength == .hard ? .hard : .soft,
            contextProvider: XcodeProjectContextBridge.shared
        ) else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(self.t)preflightError 结果为空")
            }
            return nil
        }

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.warning("\(self.t)preflightError: \(error.localizedDescription)")
        }
        return EditorLanguageFeatureError(
            domain: "xcode.semantic",
            code: error.category,
            message: error.localizedDescription,
            suggestion: error.suggestedAction
        )
    }

    func missingResultMessage(
        uri: String?,
        operation: String,
        symbolName: String?
    ) -> String? {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)missingResultMessage operation=\(operation), symbol=\(symbolName ?? "nil")")
        }
        let message = XcodeSemanticAvailability.missingResultMessage(
            uri: uri,
            operation: operation,
            symbolName: symbolName,
            contextProvider: XcodeProjectContextBridge.shared
        )
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)missingResultMessage 结果: \(message ?? "nil")")
        }
        return message
    }

    private func mapSeverity(
        _ severity: XcodeSemanticAvailability.ReasonSeverity
    ) -> EditorSemanticAvailabilitySeverity {
        switch severity {
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}
