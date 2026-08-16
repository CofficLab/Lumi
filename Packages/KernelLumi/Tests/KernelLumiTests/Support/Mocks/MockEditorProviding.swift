import Foundation
@testable import KernelLumi

/// 测试用 `EditorProviding` 实现（legacy 视图/主题契约）。
@MainActor
final class MockEditorProviding: EditorProviding {
    var currentFilePath: String?
    var currentThemeId: String = "default"
    var allEditorThemes: [EditorThemeInfo] = []

    func openFile(at path: String) async throws {
        currentFilePath = path
    }

    func closeFile(at path: String) async {
        if currentFilePath == path {
            currentFilePath = nil
        }
    }

    func setCurrentTheme(_ themeId: String) throws {
        currentThemeId = themeId
    }

    func registerEditorTheme(_ theme: EditorThemeInfo) {
        allEditorThemes.append(theme)
    }

    func unregisterEditorTheme(themeId: String) {
        allEditorThemes.removeAll { $0.id == themeId }
    }
}
