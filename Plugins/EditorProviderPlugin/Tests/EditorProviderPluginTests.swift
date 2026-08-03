import Combine
import EditorService
import Foundation
import LumiKernel
import LumiUI
import SwiftUI
import Testing
@testable import EditorProviderPlugin

@MainActor
@Suite("Editor Provider Plugin")
struct EditorProviderPluginTests {
    @Test
    func currentProjectFileOpensInEditor() async throws {
        let kernel = LumiKernel()
        let project = MockProjectService()
        try kernel.registerProject(project)

        let editorService = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        try kernel.registerService(EditorService.self, editorService)

        let plugin = EditorProviderPlugin()
        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)

        let fileURL = try makeTemporarySwiftFile()
        project.updateCurrentFile(fileURL)

        await waitForEditorFile(editorService, expected: fileURL.standardizedFileURL)
    }

    @Test
    func onReadyInstallsLumiThemeContributorRegistration() async throws {
        let previousRegistration = EditorSettingsLifecycle.registerEditorThemeContributors
        defer {
            EditorSettingsLifecycle.registerEditorThemeContributors = previousRegistration
        }

        let kernel = LumiKernel()
        let themeRegistry = LumiUIThemeRegistry()
        try themeRegistry.replaceAll([
            LumiUIThemeContribution(
                sortKey: ThemeSortKey(pluginOrder: 10, themeId: "test-dracula"),
                chromeTheme: TestChromeTheme(),
                editorThemeId: "test-dracula"
            ),
        ])
        try kernel.registerThemeService(MockThemeService(themeRegistry: themeRegistry))

        let editorService = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        try kernel.registerService(EditorService.self, editorService)

        let plugin = EditorProviderPlugin()
        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)

        let registry = EditorExtensionRegistry()
        EditorSettingsLifecycle.registerEditorThemeContributors?(registry)

        #expect(registry.theme(for: "xcode-dark") != nil)
        #expect(registry.theme(for: "test-dracula") != nil)
    }

    private func makeTemporarySwiftFile() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Lumi")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileURL = directoryURL.appendingPathComponent("Main.swift")
        try "struct Main {}\n".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func waitForEditorFile(
        _ editorService: EditorService,
        expected: URL
    ) async {
        for _ in 0 ..< 100 {
            if editorService.files.currentFileURL == expected {
                return
            }
            await Task.yield()
        }

        Issue.record("Expected editor current file to update to \(expected.path)")
    }
}

@MainActor
private final class MockThemeService: UIThemeProviding {
    let themeRegistry: LumiUIThemeRegistry

    init(themeRegistry: LumiUIThemeRegistry) {
        self.themeRegistry = themeRegistry
    }

    var themes: [LumiUIThemeContribution] { themeRegistry.themes }
    var selectedThemeId: String? { themeRegistry.selectedThemeId }
    var selectedContribution: LumiUIThemeContribution? { themeRegistry.selectedContribution }

    func themeContributions() -> [LumiUIThemeContribution] { themeRegistry.themes }

    func selectTheme(id: String) throws {
        try themeRegistry.select(themeId: id)
    }

    func registerTheme(_ contribution: LumiUIThemeContribution) {
        try? themeRegistry.replaceAll(themeRegistry.themes + [contribution])
    }

    func unregisterTheme(id: String) {
        let remaining = themeRegistry.themes.filter { $0.id != id }
        try? themeRegistry.replaceAll(remaining)
    }

    func replaceAllThemes(_ themes: [LumiUIThemeContribution]) throws {
        try themeRegistry.replaceAll(themes)
    }

    func syncToLumiUI() {}
}

private struct TestChromeTheme: LumiAppChromeTheme {
    let identifier = "test-dracula"
    let displayName = "Test Dracula"
    let compactName = "Dracula"
    let description = "Test editor syntax theme"
    let iconName = "paintpalette"
    let iconColor = Color.purple
    let appearanceKind: ThemeAppearanceKind = .dark

    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        .preset(.dracula)
    }

    func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (.purple, .pink, .cyan)
    }

    func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (.black, .gray, .white)
    }

    func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (.purple.opacity(0.12), .pink.opacity(0.2), .cyan.opacity(0.28))
    }
}

@MainActor
private final class MockProjectService: ProjectProviding {
    @Published var currentProject: ProjectInfo?
    @Published var openFileURLs: [URL] = []
    @Published var currentFileURL: URL?
    @Published var projects: [ProjectInfo] = []

    func openProject(at path: String) async throws {}

    func updateCurrentFile(_ fileURL: URL?) {
        currentFileURL = fileURL?.standardizedFileURL
    }

    func updateOpenFiles(_ fileURLs: [URL]) {
        var uniqueURLs: [URL] = []
        for fileURL in fileURLs {
            let standardizedURL = fileURL.standardizedFileURL
            if !uniqueURLs.contains(standardizedURL) {
                uniqueURLs.append(standardizedURL)
            }
        }
        openFileURLs = uniqueURLs
    }

    func closeProject() async {
        currentProject = nil
        openFileURLs = []
        currentFileURL = nil
    }

    func refreshProjects() async throws {}
}
