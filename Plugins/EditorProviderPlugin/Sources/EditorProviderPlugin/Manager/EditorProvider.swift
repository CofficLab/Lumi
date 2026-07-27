import Foundation
import SwiftUI
import LumiKernel
import EditorService
import SuperLogKit

@MainActor
public final class EditorProvider: EditorProviding, SuperLog {
    public static let emoji = "🍚"
    static let verbose: Bool = true
    
    /// 注入的具象 EditorService(弱引用,避免循环)。
    /// 在 OnReady 阶段由 plugin 注入;在此之前文件操作走降级路径。
    private weak var editorService: EditorService?

    /// 内核引用,用于在主题变更时解析当前编辑器主题。弱引用避免循环。
    private weak var kernel: LumiKernel?

    /// `.themeDidChange` 订阅令牌,重复绑定时会先移除旧令牌。
    private var themeObserver: NSObjectProtocol?

    public var currentThemeId: String = "default"

    private var themes: [String: EditorThemeInfo] = [:]

    /// 降级用的本地缓存,仅在 EditorService 未注入时使用。
    private var stubCurrentFilePath: String?

    /// 在 EditorService 注入前暂存的编辑器插件,注入后回放注册,确保注册不丢失。
    private var pendingPlugins: [any EditorPlugin] = []

    public var allEditorThemes: [EditorThemeInfo] {
        Array(themes.values)
    }

    /// 注入具象 EditorService,启用文件操作转发。
    func attachEditorService(_ service: EditorService) {
        editorService = service
        flushPendingPlugins()
    }

    /// 回放注入前暂存的编辑器插件注册。
    private func flushPendingPlugins() {
        guard let editorService else { return }
        for plugin in pendingPlugins {
            plugin.registerExtensions(into: editorService.editorExtensions)
        }
        pendingPlugins.removeAll()
    }

    // MARK: - Editor Plugin Registration

    /// 注册一个编辑器插件。插件在 `registerExtensions(into:)` 中写入编辑器运行时扩展表。
    /// 若 EditorService 尚未注入,则暂存并在注入后回放,保证注册不丢失。
    public func registerEditorPlugin(_ plugin: any EditorPlugin) {
        guard let editorService else {
            pendingPlugins.append(plugin)
            return
        }
        plugin.registerExtensions(into: editorService.editorExtensions)
    }

    public var currentFilePath: String? {
        if let url = editorService?.files.currentFileURL {
            return url.path
        }
        return stubCurrentFilePath
    }

    public func openFile(at path: String) async throws {
        if let service = editorService {
            let url = URL(fileURLWithPath: path)
            service.sessions.open(at: url)
            return
        }
        // 降级:EditorService 尚未注入时仅记录路径。
        stubCurrentFilePath = path
    }

    public func closeFile(at path: String) async {
        if let service = editorService {
            let url = URL(fileURLWithPath: path)
            // EditorService 目前没有按 URL 关闭单个 session 的公开 API;
            // 这里以"切到 nil"近似:若关闭的是当前文件,则清空当前 URL。
            if service.files.currentFileURL == url {
                service.sessions.openFile(at: nil)
            }
            return
        }
        if stubCurrentFilePath == path {
            stubCurrentFilePath = nil
        }
    }

    public func setCurrentTheme(_ themeId: String) throws {
        guard themes[themeId] != nil else {
            throw LumiKernelError.serviceNotAvailable(service: "Editor theme '\(themeId)' not found")
        }
        currentThemeId = themeId
    }

    public func registerEditorTheme(_ theme: EditorThemeInfo) {
        themes[theme.id] = theme
    }

    public func unregisterEditorTheme(themeId: String) {
        themes.removeValue(forKey: themeId)
    }

    // MARK: - Theme Sync

    /// 订阅内核 `.themeDidChange` 事件,并在订阅时立即应用一次当前编辑器主题。
    /// ThemeManager 不知道编辑器的存在,只广播事件;这里自行解析并应用。
    func bindThemeSync(kernel: LumiKernel) {
        self.kernel = kernel
        applyThemeFromKernel()

        if let previous = themeObserver {
            NotificationCenter.default.removeObserver(previous)
        }
        themeObserver = NotificationCenter.default.addObserver(
            forName: .lumiThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyThemeFromKernel()
        }
    }

    /// 从内核主题注册表解析当前应选用的编辑器主题并应用。
    private func applyThemeFromKernel() {
        guard let registry = kernel?.theme?.themeRegistry else { return }
        guard let editorThemeId = registry.resolvedEditorThemeId(colorScheme: registry.systemColorScheme) else {
            return
        }
        try? setCurrentTheme(editorThemeId)
        // 真正驱动编辑器语法高亮的是 EditorState.currentTheme，它由 EditorHostEnvironment
        // 的 themeDidChange 通知触发刷新（见 EditorConfigController.observeThemeChanges）。
        // ThemeManager 只广播内核事件、不知道 Editor 的存在，因此由本插件在边界处把内核主题
        // 事件桥接为编辑器内部的主题通知，使 EditorState 同步最新的配色。
        postEditorThemeDidChange(editorThemeId)
    }

    private func postEditorThemeDidChange(_ editorThemeId: String) {
        let notificationName = EditorHostEnvironment.current.notifications.themeDidChange
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: ["editorThemeId": editorThemeId]
        )
    }
}
