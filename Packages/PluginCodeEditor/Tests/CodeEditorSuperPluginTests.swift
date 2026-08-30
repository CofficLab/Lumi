import Combine
import EditorContracts
import EditorService
import Foundation
import KernelCore
import PluginCodeEditorHost
@testable import PluginCodeEditor
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderPluginControl
import ProviderProject
import ProviderRootView
import SwiftUI
import Testing

@MainActor
struct CodeEditorSuperPluginTests {
    @Test("is user configurable and disabled by default")
    func metadata() {
        let plugin = CodeEditorSuperPlugin()
        #expect(plugin.metadata.policy == .disabledByDefault)
        #expect(plugin.dependencies == [
            "com.coffic.lumi.plugin.editor-host"
        ])
    }

    @Test("本地化资源覆盖元数据与手册文案")
    func localizationCatalogProvidesSupportedLocales() {
        let plugin = CodeEditorSuperPlugin()
        let description = "Browse projects and edit source files in a VS Code-style workspace."

        #expect(plugin.metadata.name == CodeEditorLocalization.string("Code Editor"))
        #expect(plugin.metadata.description == CodeEditorLocalization.string(description))
        #expect(!CodeEditorLocalization.string("User Manual").isEmpty)
        #expect(!CodeEditorLocalization.string("Open a File").isEmpty)
    }

    @Test("enabling and disabling installs and removes workspace contributions")
    func lifecycle() async throws {
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let content = TestContentProvider()
        let docs = DefaultDocsViewProviding()
        let project = DefaultProjectProvider()
        let rootView = DefaultRootViewProvider()
        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider((any ContentViewProviding).self, content)
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        try kernel.registerProvider((any ProjectProviding).self, project)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        let workspace = CodeEditorSuperPlugin()
        try kernel.start(plugins: [CodeEditorHostSuperPlugin(), workspace])
        let control = DefaultPluginControlling(kernel: kernel)

        #expect(docs.aboutEntries.map(\.id) == [workspace.id])
        #expect(docs.manualEntries.map(\.id) == [workspace.id])
        #expect(activity.items.allSatisfy { $0.id != CodeEditorSuperPlugin.activityItemID })
        #expect(await control.enablePlugin(id: workspace.id))
        #expect(activity.items.filter { $0.id == CodeEditorSuperPlugin.activityItemID }.count == 1)
        activity.activateItem(id: CodeEditorSuperPlugin.activityItemID)
        #expect(content.setCount == 1)
        #expect(rootView.isContentHeaderViewHidden == false)

        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeEditorPlugin-\(UUID().uuidString).swift")
        try "let value = 1\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        project.updateCurrentFile(file)
        await waitForFileLoad(editor: try #require(kernel.resolveProvider(EditorService.self)))

        let editor = try #require(kernel.resolveProvider(EditorService.self))
        #expect(editor.files.currentFileURL == file.standardizedFileURL)
        #expect(editor.files.content?.string == "let value = 1\n")

        #expect(await control.disablePlugin(id: workspace.id))
        #expect(activity.items.allSatisfy { $0.id != CodeEditorSuperPlugin.activityItemID })
        #expect(content.clearCount == 1)
        #expect(rootView.isContentHeaderViewHidden)

        #expect(await control.enablePlugin(id: workspace.id))
        #expect(activity.items.filter { $0.id == CodeEditorSuperPlugin.activityItemID }.count == 1)
    }

    private func waitForFileLoad(editor: EditorService) async {
        for _ in 0..<100 where editor.state.isFileLoadInProgress {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
private final class TestContentProvider: ContentViewProviding {
    @Published private var revision = 0
    private(set) var setCount = 0
    private(set) var clearCount = 0

    func setContentView(_ view: AnyView?) {
        if view == nil { clearCount += 1 } else { setCount += 1 }
        revision += 1
    }

    func makeContentView() -> AnyView { AnyView(EmptyView()) }
}
