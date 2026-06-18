@testable import EditorSwiftPlugin
@testable import EditorService
import EditorLanguageRuntime
import Foundation
import Testing

@MainActor
@Test func swiftRunCommandOnlyForSwiftFiles() {
    let contributor = SwiftRunCommandContributor()
    let state = EditorState(editorExtensions: EditorExtensionRegistry())
    let swiftDescriptor = EditorLanguageDescriptor(
        languageId: "swift",
        displayName: "Swift",
        fileExtensions: ["swift"]
    )
    state.detectedLanguage = EditorLanguageContext(descriptor: swiftDescriptor)

    let swiftCommands = contributor.provideCommands(
        context: EditorCommandContext(languageId: "swift", hasSelection: false, line: 1, character: 1),
        state: state,
        textView: nil
    )
    #expect(swiftCommands.count == 1)
    #expect(swiftCommands[0].id == "swift.run")
    #expect(swiftCommands[0].shortcut?.key == "r")
    if let shortcut = swiftCommands[0].shortcut {
        #expect(shortcut.modifiers == [.command])
    } else {
        Issue.record("Expected Run shortcut")
    }

    let goCommands = contributor.provideCommands(
        context: EditorCommandContext(languageId: "go", hasSelection: false, line: 1, character: 1),
        state: state,
        textView: nil
    )
    #expect(goCommands.isEmpty)
}

@MainActor
@Test func swiftBuildRunManagerCanRunWhenIdle() async {
    let manager = SwiftBuildRunManager()
    #expect(manager.canRun == true)

    await manager.refreshPreflight(
        provider: nil,
        projectPath: nil,
        currentFileURL: nil
    )
    #expect(manager.canRun == false)
    #expect(manager.runDisabledReason != nil)
}

@MainActor
@Test func statusBarViewModelShowsSPMPackage() throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let manifest = """
    // swift-tools-version: 5.9
    import PackageDescription

    let package = Package(
        name: "DemoPkg",
        targets: [
            .executableTarget(name: "DemoPkg"),
        ]
    )
    """
    try manifest.write(
        to: tempDir.appendingPathComponent("Package.swift"),
        atomically: true,
        encoding: .utf8
    )

    let viewModel = XcodeProjectStatusBarViewModel()
    viewModel.refreshSwiftPackageStateForTesting(projectPath: tempDir.path)

    #expect(viewModel.isSwiftPackageProject == true)
    #expect(viewModel.spmPackageName == tempDir.lastPathComponent)
    #expect(viewModel.spmExecutableTarget == "DemoPkg")
    #expect(viewModel.showsBuildToolbar == true)
}
