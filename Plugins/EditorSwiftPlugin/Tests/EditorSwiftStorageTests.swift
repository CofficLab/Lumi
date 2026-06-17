@testable import EditorSwiftPlugin
import Testing
import XcodeKit

@Test func editorSwiftStorageUsesPluginDirectoryAndWorkspaceHash() {
    let workspacePath = "/tmp/Example.xcodeproj"
    let store = EditorSwiftBuildServerStore.makeStore()
    let projectStore = EditorSwiftStorage.projectStoreDirectory(forWorkspacePath: workspacePath)
    let derivedData = EditorSwiftStorage.derivedDataDirectory(forWorkspacePath: workspacePath)

    #expect(projectStore.path.contains(EditorSwiftStorage.pluginName))
    #expect(projectStore == store.derivedDataDirectory(forWorkspace: workspacePath).deletingLastPathComponent())
    #expect(derivedData.path.hasSuffix("/DerivedData"))
    #expect(derivedData.deletingLastPathComponent() == projectStore)
}
