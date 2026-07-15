import Foundation
import XcodeKit

/// EditorSwiftPlugin storage paths for build server metadata and Xcode DerivedData.
///
/// Layout: `<LumiCore.dataRootDirectory>/EditorSwiftPlugin/<workspace-hash>/`
public enum EditorSwiftStorage {
    public static let pluginName = EditorSwiftBuildServerStore.pluginDirectoryName

    public static var rootDirectory: URL {
        EditorSwiftBuildServerStore.makeStore().pluginDirectoryURL
    }

    public static func projectStoreDirectory(forWorkspacePath workspacePath: String) -> URL {
        derivedDataDirectory(forWorkspacePath: workspacePath).deletingLastPathComponent()
    }

    public static func derivedDataDirectory(forWorkspacePath workspacePath: String) -> URL {
        EditorSwiftBuildServerStore.makeStore().derivedDataDirectory(forWorkspace: workspacePath)
    }

    public static func purgeBuildCaches(forWorkspacePath workspacePath: String) {
        let directory = derivedDataDirectory(forWorkspacePath: workspacePath)
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public static func clearWorkspaceData(forWorkspacePath workspacePath: String) {
        let directory = projectStoreDirectory(forWorkspacePath: workspacePath)
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
