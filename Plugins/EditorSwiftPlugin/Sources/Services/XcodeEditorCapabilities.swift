import EditorService
import Foundation
import os
import SuperLogKit
import XcodeKit

@MainActor
public final class XcodeProjectContextCapabilityAdapter: SuperEditorProjectContextCapability, SuperLog {
    public nonisolated static let emoji = "📁"

    public let id = "XcodeProjectContextCapability"
    private let bridge: XcodeProjectContextBridge

    public init(bridge: XcodeProjectContextBridge = .shared) {
        self.bridge = bridge
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)初始化完成")
            }
        }
    }

    public func canHandleProject(at path: String?) -> Bool {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(self.t)canHandleProject: 路径为空 -> false")
                }
            }
            return false
        }
        if let cachedState = bridge.cachedState, cachedState.projectPath == path {
            XcodeProjectCapabilityCache.set(cachedState.isXcodeProject, for: path)
            return cachedState.isXcodeProject
        }
        if let cached = XcodeProjectCapabilityCache.value(for: path) {
            return cached
        }
        let canHandle = XcodeProjectResolver.isXcodeProjectRoot(URL(filePath: path))
        XcodeProjectCapabilityCache.set(canHandle, for: path)
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)canHandleProject: \(path) -> \(canHandle)")
            }
        }
        return canHandle
    }

    public func projectOpened(at path: String) async {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)projectOpened 开始: \(path)")
            }
        }
        await bridge.projectOpened(at: path)
        XcodeProjectCapabilityCache.set(bridge.isXcodeProject, for: path)
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)projectOpened 完成: \(path)")
            }
        }
    }

    public func projectClosed() {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)projectClosed")
            }
        }
        bridge.projectClosed()
    }

    public func resyncProjectContext() async {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)resyncProjectContext 开始")
            }
        }
        await bridge.resyncBuildContext()
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)resyncProjectContext 完成")
            }
        }
    }

    public func makeEditorContextSnapshot(currentFileURL: URL?) -> EditorProjectContextSnapshot? {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)makeEditorContextSnapshot，currentFile: \(currentFileURL?.path ?? "nil")")
            }
        }
        guard let snapshot = bridge.makeEditorContextSnapshot(currentFileURL: currentFileURL) else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(self.t)snapshot 为空")
                }
            }
            return nil
        }
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)snapshot 创建成功，workspace: \(snapshot.workspaceName), scheme: \(snapshot.activeScheme ?? "nil")")
            }
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
            currentFileIsInTarget: snapshot.currentFileIsInTarget,
            isTargetMembershipResolved: snapshot.isTargetMembershipResolved
        )
    }

    public func updateLatestEditorSnapshot(_ snapshot: EditorProjectContextSnapshot?) {
        guard let snapshot else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(self.t)updateLatestEditorSnapshot: nil")
                }
            }
            bridge.updateLatestEditorSnapshot(nil)
            return
        }
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)updateLatestEditorSnapshot: workspace=\(snapshot.workspaceName), file=\(snapshot.currentFilePath ?? "nil")")
            }
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
                currentFileIsInTarget: snapshot.currentFileIsInTarget,
                isTargetMembershipResolved: snapshot.isTargetMembershipResolved
            )
        )
    }

    private func status(from description: String) -> EditorProjectContextStatus {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)状态映射: \(description)")
            }
        }
        return XcodeProjectContextStatusMapper.map(description: description)
    }
}

@MainActor
public final class XcodeLanguageIntegrationCapabilityAdapter: SuperEditorLanguageIntegrationCapability, SuperLog {
    public nonisolated static let emoji = "🧩"

    public let id = "XcodeLanguageIntegrationCapability"
    private let bridge: XcodeProjectContextBridge

    public init(bridge: XcodeProjectContextBridge = .shared) {
        self.bridge = bridge
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)初始化完成")
            }
        }
    }

    public func supports(languageId: String, projectPath: String?) -> Bool {
        guard languageId == "swift" || languageId == "sourcekit" else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(self.t)supports: languageId=\(languageId) 不支持")
                }
            }
            return false
        }
        guard let projectPath, !projectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(self.t)supports: projectPath 为空")
                }
            }
            return false
        }
        if let cachedState = bridge.cachedState, cachedState.projectPath == projectPath {
            XcodeProjectCapabilityCache.set(cachedState.isXcodeProject, for: projectPath)
            return cachedState.isXcodeProject
        }
        if let cached = XcodeProjectCapabilityCache.value(for: projectPath) {
            return cached
        }
        let supported = XcodeProjectResolver.isXcodeProjectRoot(URL(filePath: projectPath))
        XcodeProjectCapabilityCache.set(supported, for: projectPath)
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)supports: language=\(languageId), project=\(projectPath) -> \(supported)")
            }
        }
        return supported
    }

    public func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]? {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)workspaceFolders 请求，language=\(languageId), project=\(projectPath)")
            }
        }
        guard supports(languageId: languageId, projectPath: projectPath),
              let folders = bridge.makeWorkspaceFolders(),
              !folders.isEmpty else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(self.t)workspaceFolders 为空")
                }
            }
            return nil
        }
        let result: [EditorWorkspaceFolder] = folders.compactMap { (item: [String: String]) -> EditorWorkspaceFolder? in
            guard let uri = item["uri"], let name = item["name"] else { return nil }
            return EditorWorkspaceFolder(uri: uri, name: name)
        }
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)workspaceFolders 返回 \(result.count) 项")
            }
        }
        return result
    }

    public func initializationOptions(for languageId: String, projectPath: String) -> [String: String]? {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)initializationOptions 请求，language=\(languageId), project=\(projectPath)")
            }
        }
        guard supports(languageId: languageId, projectPath: projectPath),
              let options = bridge.makeInitializationOptions(),
              !options.isEmpty else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(self.t)initializationOptions 为空")
                }
            }
            return nil
        }
        let result = options.reduce(into: [String: String]()) { partial, entry in
            partial[entry.key] = String(describing: entry.value)
        }
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)initializationOptions 返回 key 数: \(result.count)")
            }
        }
        return result
    }
}

@MainActor
public final class XcodeSemanticCapabilityAdapter: SuperEditorSemanticCapability, SuperLog {
    public nonisolated static let emoji = "🧠"

    public let id = "XcodeSemanticCapability"

    public func canHandle(uri: String?) -> Bool {
        guard let uri, !uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(self.t)canHandle: uri 为空 -> false")
                }
            }
            return false
        }
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)canHandle: \(uri) -> true")
            }
        }
        return true
    }

    public func inspectCurrentFileContext(uri: String?) -> EditorSemanticAvailabilityReport {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)inspectCurrentFileContext: \(uri ?? "nil")")
            }
        }
        let bridge = XcodeProjectContextBridge.shared
        let snapshot = bridge.latestEditorSnapshot
        let report: XcodeSemanticAvailability.Report
        if snapshot?.currentFilePath.flatMap({ URL(filePath: $0).absoluteString }) == uri {
            report = XcodeSemanticAvailability.inspectCurrentFileContext(
                snapshot: snapshot,
                cachedState: bridge.cachedState,
                buildContextStatus: bridge.buildContextProvider?.buildContextStatus ?? .unknown
            )
        } else {
            report = XcodeSemanticAvailability.inspectCurrentFileContext(uri: uri, contextProvider: bridge)
        }
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)inspectCurrentFileContext 完成，reasons: \(report.reasons.count)")
            }
        }
        let localizedReport = XcodeProjectStatusPresentation.localizedSemanticReport(report)
        return EditorSemanticAvailabilityReport(
            reasons: localizedReport.reasons.map { reason in
                EditorSemanticAvailabilityReason(
                    id: reason.id,
                    severity: mapSeverity(reason.severity),
                    title: reason.title,
                    message: reason.message
                )
            }
        )
    }

    public func preflightMessage(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> String? {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)preflightMessage operation=\(operation), symbol=\(symbolName ?? "nil"), strength=\(String(describing: strength))")
            }
        }
        let message = XcodeSemanticAvailability.preflightMessage(
            uri: uri,
            operation: operation,
            symbolName: symbolName,
            strength: strength == .hard ? .hard : .soft,
            contextProvider: XcodeProjectContextBridge.shared
        )
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)preflightMessage 结果: \(message ?? "nil")")
            }
        }
        return message
    }

    public func preflightError(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> EditorLanguageFeatureError? {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)preflightError operation=\(operation), symbol=\(symbolName ?? "nil"), strength=\(String(describing: strength))")
            }
        }
        guard let error = XcodeSemanticAvailability.preflightError(
            uri: uri,
            operation: operation,
            symbolName: symbolName,
            strength: strength == .hard ? .hard : .soft,
            contextProvider: XcodeProjectContextBridge.shared
        ) else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(self.t)preflightError 结果为空")
                }
            }
            return nil
        }

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.warning("\(self.t)preflightError: \(error.localizedDescription)")
            }
        }
        return EditorLanguageFeatureError(
            domain: "xcode.semantic",
            code: error.category,
            message: error.localizedDescription,
            suggestion: error.suggestedAction
        )
    }

    public func missingResultMessage(
        uri: String?,
        operation: String,
        symbolName: String?
    ) -> String? {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)missingResultMessage operation=\(operation), symbol=\(symbolName ?? "nil")")
            }
        }
        let message = XcodeSemanticAvailability.missingResultMessage(
            uri: uri,
            operation: operation,
            symbolName: symbolName,
            contextProvider: XcodeProjectContextBridge.shared
        )
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(self.t)missingResultMessage 结果: \(message ?? "nil")")
            }
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

@MainActor
private enum XcodeProjectCapabilityCache {
    private static let maxEntries = 100
    private static var values: [String: Bool] = [:]
    private static var keysByRecency: [String] = []

    public static func value(for path: String) -> Bool? {
        let key = standardizedPath(path)
        guard let value = values[key] else { return nil }
        markRecentlyUsed(key)
        return value
    }

    public static func set(_ value: Bool, for path: String) {
        let key = standardizedPath(path)
        values[key] = value
        markRecentlyUsed(key)
        trimIfNeeded()
    }

    private static func standardizedPath(_ path: String) -> String {
        URL(filePath: path).standardizedFileURL.path
    }

    private static func markRecentlyUsed(_ key: String) {
        keysByRecency.removeAll { $0 == key }
        keysByRecency.append(key)
    }

    private static func trimIfNeeded() {
        while keysByRecency.count > maxEntries {
            let oldestKey = keysByRecency.removeFirst()
            values.removeValue(forKey: oldestKey)
        }
    }
}
