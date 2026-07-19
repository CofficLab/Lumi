import Foundation
import LumiKernel
import LumiUI

/// 编辑器服务实现
@MainActor
public final class EditorService: EditorServiceProviding {

    // MARK: - 文件操作

    /// 当前文件路径
    @Published public var currentFilePath: String?

    // MARK: - 主题管理

    /// 当前编辑器主题 ID
    @Published public var currentThemeId: String = "xcode-dark"

    /// 已注册的主题字典（主题 ID -> 主题信息）
    private var registeredThemes: [String: EditorThemeInfo] = [:]

    /// 主题 ID -> 语法调色板映射
    private var themePalettes: [String: EditorSyntaxPalette] = [:]

    public init() {
        // 注册内置主题
        registerBuiltinThemes()
    }

    // MARK: - 文件操作方法

    public func openFile(at path: String) async throws {
        // TODO: 实现文件打开逻辑
        currentFilePath = path
    }

    public func closeFile(at path: String) async {
        // TODO: 实现文件关闭逻辑
        if currentFilePath == path {
            currentFilePath = nil
        }
    }

    // MARK: - 主题管理方法

    public func setCurrentTheme(_ themeId: String) throws {
        guard registeredThemes[themeId] != nil else {
            throw EditorServiceError.themeNotFound(themeId)
        }
        currentThemeId = themeId
    }

    public var allEditorThemes: [EditorThemeInfo] {
        Array(registeredThemes.values).sorted { $0.displayName < $1.displayName }
    }

    public func registerEditorTheme(_ theme: EditorThemeInfo) {
        registeredThemes[theme.id] = theme
    }

    public func unregisterEditorTheme(themeId: String) {
        registeredThemes.removeValue(forKey: themeId)
        themePalettes.removeValue(forKey: themeId)
    }

    public func editorSyntaxPalette(for themeId: String) -> EditorSyntaxPalette? {
        // 先检查自定义调色板
        if let palette = themePalettes[themeId] {
            return palette
        }

        // 返回预设调色板
        let presetMap: [String: EditorSyntaxPalettePreset] = [
            "xcode-dark": .xcodeDark,
            "xcode-light": .xcodeLight,
            "one-dark": .oneDark,
            "dracula": .dracula,
            "vscode-dark": .vscodeDark,
            "vscode-light": .vscodeLight,
            "github": .github,
            "github-dark": .githubDark,
            "lumi-dark": .lumiDark,
            "lumi-light": .lumiLight,
            "sky-dark": .skyDark,
            "sky-light": .skyLight
        ]

        guard let preset = presetMap[themeId] else {
            return nil
        }

        return EditorSyntaxPalette.preset(preset)
    }

    // MARK: - 私有方法

    /// 注册内置主题
    private func registerBuiltinThemes() {
        let builtinThemes: [EditorThemeInfo] = [
            EditorThemeInfo(id: "xcode-dark", displayName: "Xcode Dark", iconName: "moon.fill", isDark: true),
            EditorThemeInfo(id: "xcode-light", displayName: "Xcode Light", iconName: "sun.max.fill", isDark: false),
            EditorThemeInfo(id: "one-dark", displayName: "One Dark", iconName: "circle.hexagongrid", isDark: true),
            EditorThemeInfo(id: "dracula", displayName: "Dracula", iconName: "moon.stars.fill", isDark: true),
            EditorThemeInfo(id: "vscode-dark", displayName: "VS Code Dark", iconName: "moon.circle.fill", isDark: true),
            EditorThemeInfo(id: "vscode-light", displayName: "VS Code Light", iconName: "sun.max.circle.fill", isDark: false),
            EditorThemeInfo(id: "github", displayName: "GitHub", iconName: "sun.min.fill", isDark: false),
            EditorThemeInfo(id: "github-dark", displayName: "GitHub Dark", iconName: "moon.fill", isDark: true),
            EditorThemeInfo(id: "lumi-dark", displayName: "Lumi Dark", iconName: "moon.z.fill", isDark: true),
            EditorThemeInfo(id: "lumi-light", displayName: "Lumi Light", iconName: "sun.max.fill", isDark: false),
            EditorThemeInfo(id: "sky-dark", displayName: "Sky Dark", iconName: "cloud.moon.fill", isDark: true),
            EditorThemeInfo(id: "sky-light", displayName: "Sky Light", iconName: "cloud.sun.fill", isDark: false)
        ]

        for theme in builtinThemes {
            registerEditorTheme(theme)
        }
    }
}

// MARK: - 错误类型

enum EditorServiceError: Error, LocalizedError {
    case themeNotFound(String)

    var errorDescription: String? {
        switch self {
        case .themeNotFound(let themeId):
            return "Theme not found: \(themeId)"
        }
    }
}