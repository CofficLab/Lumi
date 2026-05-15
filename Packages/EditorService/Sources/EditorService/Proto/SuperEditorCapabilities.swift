import Foundation
import EditorKernel

@MainActor
public protocol SuperEditorProjectContextCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }
    func canHandleProject(at path: String?) -> Bool
    func projectOpened(at path: String) async
    func projectClosed()
    func resyncProjectContext() async
    func makeEditorContextSnapshot(currentFileURL: URL?) -> EditorProjectContextSnapshot?
    func updateLatestEditorSnapshot(_ snapshot: EditorProjectContextSnapshot?)
}

extension SuperEditorProjectContextCapability {
    public var priority: Int { 0 }

    public func canHandleProject(at path: String?) -> Bool {
        guard let path else { return false }
        return !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
public protocol SuperEditorLanguageIntegrationCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }
    func supports(languageId: String, projectPath: String?) -> Bool
    func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]?
    func initializationOptions(for languageId: String, projectPath: String) -> [String: String]?
}

extension SuperEditorLanguageIntegrationCapability {
    public var priority: Int { 0 }
}

@MainActor
public protocol SuperEditorSemanticCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }
    func canHandle(uri: String?) -> Bool
    func inspectCurrentFileContext(uri: String?) -> EditorSemanticAvailabilityReport
    func preflightMessage(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> String?
    func preflightError(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> EditorLanguageFeatureError?
    func missingResultMessage(
        uri: String?,
        operation: String,
        symbolName: String?
    ) -> String?
}

extension SuperEditorSemanticCapability {
    public var priority: Int { 0 }

    public func canHandle(uri: String?) -> Bool {
        guard let uri else { return false }
        return !uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func missingResultMessage(
        uri: String?,
        operation: String,
        symbolName: String?
    ) -> String? {
        nil
    }
}

public typealias EditorProjectContextSnapshot = EditorKernel.EditorProjectContextSnapshot
public typealias EditorProjectContextStatus = EditorKernel.EditorProjectContextStatus
public typealias EditorWorkspaceFolder = EditorKernel.EditorWorkspaceFolder
public typealias EditorSemanticPreflightStrength = EditorKernel.EditorSemanticPreflightStrength
public typealias EditorSemanticAvailabilitySeverity = EditorKernel.EditorSemanticAvailabilitySeverity
public typealias EditorSemanticAvailabilityReason = EditorKernel.EditorSemanticAvailabilityReason
public typealias EditorSemanticAvailabilityReport = EditorKernel.EditorSemanticAvailabilityReport
public typealias EditorLanguageFeatureError = EditorKernel.EditorLanguageFeatureError
