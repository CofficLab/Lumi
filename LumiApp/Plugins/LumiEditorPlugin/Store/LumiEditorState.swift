import Foundation
import AppKit
import Combine
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages

/// 编辑器状态管理器
/// 管理当前文件的内容（NSTextStorage）、光标位置、编辑器配置等
@MainActor
final class LumiEditorState: ObservableObject {
    
    // MARK: - File State
    
    /// 当前文件 URL
    @Published private(set) var currentFileURL: URL?
    
    /// 当前文件内容（NSTextStorage，CodeEditSourceEditor 要求）
    @Published var content: NSTextStorage?
    
    /// 上次持久化的内容哈希（用于检测变更）
    private var persistedContentHash: Int?
    
    /// 当前文件是否可编辑
    @Published var isEditable: Bool = true
    
    /// 当前文件是否为截断预览
    @Published var isTruncated: Bool = false
    
    /// 当前文件是否可预览
    @Published var canPreview: Bool = false
    
    /// 文件扩展名
    @Published var fileExtension: String = ""
    
    /// 文件名
    @Published var fileName: String = ""
    
    /// 当前项目根路径（由 LumiEditorRootView 设置，用于计算相对路径）
    var projectRootPath: String?
    
    /// 当前文件相对于项目根目录的路径（用于构建选区位置信息）
    /// 若无项目则返回文件名
    var relativeFilePath: String {
        guard let url = currentFileURL else { return "" }
        guard let projectPath = projectRootPath else {
            return url.lastPathComponent
        }
        let absolutePath = url.path
        guard absolutePath.hasPrefix(projectPath) else {
            return url.lastPathComponent
        }
        var relative = String(absolutePath.dropFirst(projectPath.count))
        if relative.hasPrefix("/") {
            relative = String(relative.dropFirst())
        }
        return relative
    }
    
    // MARK: - Editor State
    
    /// 编辑器状态（光标位置、滚动位置、查找文本等）
    @Published var editorState = SourceEditorState()
    
    /// 当前行号
    @Published var cursorLine: Int = 1
    
    /// 当前列号
    @Published var cursorColumn: Int = 1
    
    /// 总行数
    @Published var totalLines: Int = 0
    
    /// 检测到的语言
    @Published var detectedLanguage: CodeLanguage?
    
    // MARK: - Theme
    
    /// 当前主题预设
    @Published var themePreset: LumiEditorThemeAdapter.PresetTheme = .xcodeDark
    
    /// 当前主题（缓存，避免每次重建）
    @Published private(set) var currentTheme: EditorTheme?
    
    // MARK: - Configuration
    
    /// 字体大小
    @Published var fontSize: Double = 13.0
    
    /// Tab 宽度
    @Published var tabWidth: Int = 4
    
    /// 是否使用空格替代 Tab
    @Published var useSpaces: Bool = true
    
    /// 是否自动换行
    @Published var wrapLines: Bool = true
    
    /// 是否显示 Minimap
    @Published var showMinimap: Bool = true
    
    /// 是否显示行号
    @Published var showGutter: Bool = true
    
    /// 是否显示代码折叠
    @Published var showFoldingRibbon: Bool = true
    
    // MARK: - Auto Save
    
    /// 是否有未保存的变更
    @Published var hasUnsavedChanges: Bool = false
    
    /// 保存状态
    @Published var saveState: SaveState = .idle
    
    /// 防抖保存任务
    private var saveTask: Task<Void, Never>?
    
    /// 成功状态清除任务
    private var successClearTask: Task<Void, Never>?
    
    /// 自动保存延迟（秒）
    static let autoSaveDelay: TimeInterval = 1.5
    
    /// 成功状态显示时间（秒）
    static let successDisplayDuration: TimeInterval = 2.0
    
    // MARK: - File Loading Constants
    
    /// 文本探测字节数
    static let textProbeBytes = 8192
    
    /// 只读阈值（512KB）
    static let readOnlyThreshold: Int64 = 512 * 1024
    
    /// 截断阈值（2MB）
    static let truncationThreshold: Int64 = 2 * 1024 * 1024
    
    /// 截断读取字节数（256KB）
    static let truncationReadBytes: Int = 256 * 1024
    
    // MARK: - Save State Enum
    
    enum SaveState: Equatable {
        case idle
        case editing
        case saving
        case saved
        case error(String)
        
        var icon: String {
            switch self {
            case .idle: return "checkmark.circle"
            case .editing: return "pencil.circle"
            case .saving: return "arrow.triangle.2.circlepath"
            case .saved: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
        
        var label: String {
            switch self {
            case .idle: return String(localized: "No Changes", table: "LumiEditor")
            case .editing: return String(localized: "Editing...", table: "LumiEditor")
            case .saving: return String(localized: "Saving...", table: "LumiEditor")
            case .saved: return String(localized: "Saved", table: "LumiEditor")
            case .error(let msg): return msg
            }
        }
    }
    
    // MARK: - Init
    
    init() {
        restoreConfig()
    }
    
    // MARK: - Config Persistence
    
    /// 从持久化存储恢复配置
    private func restoreConfig() {
        if let fs = LumiEditorConfigStore.loadDouble(forKey: LumiEditorConfigStore.fontSizeKey) {
            fontSize = fs
        }
        if let tw = LumiEditorConfigStore.loadInt(forKey: LumiEditorConfigStore.tabWidthKey) {
            tabWidth = tw
        }
        if let us = LumiEditorConfigStore.loadBool(forKey: LumiEditorConfigStore.useSpacesKey) {
            useSpaces = us
        }
        if let wl = LumiEditorConfigStore.loadBool(forKey: LumiEditorConfigStore.wrapLinesKey) {
            wrapLines = wl
        }
        if let sm = LumiEditorConfigStore.loadBool(forKey: LumiEditorConfigStore.showMinimapKey) {
            showMinimap = sm
        }
        if let sg = LumiEditorConfigStore.loadBool(forKey: LumiEditorConfigStore.showGutterKey) {
            showGutter = sg
        }
        if let sf = LumiEditorConfigStore.loadBool(forKey: LumiEditorConfigStore.showFoldingRibbonKey) {
            showFoldingRibbon = sf
        }
        // 恢复主题
        if let themeRaw = LumiEditorConfigStore.loadString(forKey: LumiEditorConfigStore.themeNameKey),
           let preset = LumiEditorThemeAdapter.PresetTheme(rawValue: themeRaw) {
            themePreset = preset
        }
        currentTheme = LumiEditorThemeAdapter.theme(from: themePreset)
    }
    
    /// 持久化当前配置
    func persistConfig() {
        LumiEditorConfigStore.saveValue(fontSize, forKey: LumiEditorConfigStore.fontSizeKey)
        LumiEditorConfigStore.saveValue(tabWidth, forKey: LumiEditorConfigStore.tabWidthKey)
        LumiEditorConfigStore.saveValue(useSpaces, forKey: LumiEditorConfigStore.useSpacesKey)
        LumiEditorConfigStore.saveValue(wrapLines, forKey: LumiEditorConfigStore.wrapLinesKey)
        LumiEditorConfigStore.saveValue(showMinimap, forKey: LumiEditorConfigStore.showMinimapKey)
        LumiEditorConfigStore.saveValue(showGutter, forKey: LumiEditorConfigStore.showGutterKey)
        LumiEditorConfigStore.saveValue(showFoldingRibbon, forKey: LumiEditorConfigStore.showFoldingRibbonKey)
        LumiEditorConfigStore.saveValue(themePreset.rawValue, forKey: LumiEditorConfigStore.themeNameKey)
    }
    
    /// 切换主题
    func setTheme(_ preset: LumiEditorThemeAdapter.PresetTheme) {
        themePreset = preset
        currentTheme = LumiEditorThemeAdapter.theme(from: preset)
        persistConfig()

        // 通知终端插件同步更新颜色
        NotificationCenter.default.post(
            name: .lumiEditorThemeDidChange,
            object: nil,
            userInfo: ["theme": preset]
        )
    }
    
    // MARK: - File Loading
    
    /// 加载指定文件
    func loadFile(from url: URL?) {
        // 清理旧状态
        saveTask?.cancel()
        saveTask = nil
        successClearTask?.cancel()
        successClearTask = nil
        
        guard let url = url else {
            resetState()
            return
        }
        
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            resetState()
            return
        }
        
        let loadingURL = url
        
        Task {
            do {
                let fileSize = Int64((try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                
                guard try isLikelyTextFile(url: url) else {
                    await MainActor.run { [weak self] in
                        self?.resetState()
                    }
                    return
                }
                
                let shouldTruncate = fileSize > Self.truncationThreshold
                let shouldReadOnly = fileSize > Self.readOnlyThreshold
                
                let content: String
                if shouldTruncate {
                    content = try readTruncatedContent(from: url, maxBytes: Self.truncationReadBytes)
                } else {
                    var detectedEncoding = String.Encoding.utf8
                    content = try String(contentsOf: url, usedEncoding: &detectedEncoding)
                }
                
                await MainActor.run { [weak self] in
                    guard let self, self.currentFileURL != loadingURL || self.content == nil else { return }
                    
                    self.currentFileURL = loadingURL
                    self.content = NSTextStorage(string: content)
                    self.persistedContentHash = content.hashValue
                    self.canPreview = true
                    self.isEditable = !shouldReadOnly
                    self.isTruncated = shouldTruncate
                    self.fileExtension = loadingURL.pathExtension.lowercased()
                    self.fileName = loadingURL.lastPathComponent
                    self.hasUnsavedChanges = false
                    self.saveState = .idle
                    
                    // 检测语言
                    self.detectedLanguage = CodeLanguage.detectLanguageFrom(
                        url: loadingURL,
                        prefixBuffer: content.getFirstLines(5),
                        suffixBuffer: content.getLastLines(5)
                    )
                    
                    // 计算行数
                    self.totalLines = content.filter { $0 == "\n" }.count + 1
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.resetState()
                }
            }
        }
    }
    
    /// 重置状态
    private func resetState() {
        currentFileURL = nil
        content = nil
        persistedContentHash = nil
        canPreview = false
        isEditable = true
        isTruncated = false
        fileExtension = ""
        fileName = ""
        hasUnsavedChanges = false
        saveState = .idle
        detectedLanguage = nil
        cursorLine = 1
        cursorColumn = 1
        totalLines = 0
    }
    
    // MARK: - Content Change Detection
    
    /// 通知内容已变更（由 TextViewCoordinator 调用）
    func notifyContentChanged() {
        guard let content = content?.string, let currentHash = persistedContentHash else { return }
        
        let newHash = content.hashValue
        if newHash != currentHash {
            hasUnsavedChanges = true
            saveState = .editing
            scheduleAutoSave(content: content)
        } else {
            hasUnsavedChanges = false
            saveState = .idle
        }
    }
    
    // MARK: - Auto Save
    
    /// 安排自动保存
    private func scheduleAutoSave(content: String) {
        saveTask?.cancel()
        
        let fileURL = currentFileURL
        
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.autoSaveDelay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.performSave(content: content, to: fileURL)
            }
        }
    }
    
    /// 立即保存
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        
        guard let content = content?.string, let fileURL = currentFileURL else { return }
        performSave(content: content, to: fileURL)
    }
    
    /// 执行保存
    private func performSave(content: String, to url: URL?) {
        guard let url else { return }
        
        saveState = .saving
        
        // 使用普通 Task（继承 MainActor 隔离），文件 I/O 通过 withCheckedThrowingContinuation 移到后台线程
        // 避免 Task.detached 导致的 "sending self risks causing data races" 编译错误
        Task {
            do {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    saveState = .error(String(localized: "File not found", table: "LumiEditor"))
                    scheduleSuccessClear()
                    return
                }
                
                // 在后台线程执行文件写入，不阻塞 MainActor
                let contentCopy = content
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try contentCopy.write(to: url, atomically: true, encoding: .utf8)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                persistedContentHash = content.hashValue
                hasUnsavedChanges = false
                saveState = .saved
                scheduleSuccessClear()
            } catch {
                saveState = .error(String(localized: "Save failed: \(error.localizedDescription)", table: "LumiEditor"))
                scheduleSuccessClear()
            }
        }
    }
    
    /// 安排成功状态清除
    private func scheduleSuccessClear() {
        successClearTask?.cancel()
        successClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.successDisplayDuration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if case .saved = self?.saveState {
                    self?.saveState = .idle
                }
            }
        }
    }
    
    // MARK: - File Helpers
    
    /// 读取截断内容
    private func readTruncatedContent(from url: URL, maxBytes: Int) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        let data = try handle.read(upToCount: maxBytes) ?? Data()
        let preview = String(decoding: data, as: UTF8.self)
        let suffix = "\n\n… " + String(localized: "File too large. Preview is truncated.", table: "LumiEditor")
        return preview + suffix
    }
    
    /// 检测文件是否为文本文件
    private func isLikelyTextFile(url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        let sample = try handle.read(upToCount: Self.textProbeBytes) ?? Data()
        if sample.isEmpty { return true }
        
        // 包含 null 字节则不是文本文件
        if sample.contains(0) { return false }
        
        // 计算控制字符比例
        var controlByteCount = 0
        for byte in sample {
            if byte == 0x09 || byte == 0x0A || byte == 0x0D { continue }
            if byte < 0x20 { controlByteCount += 1 }
        }
        
        let ratio = Double(controlByteCount) / Double(sample.count)
        return ratio < 0.05
    }
}

// MARK: - String Helpers

private extension String {
    func getFirstLines(_ count: Int) -> String? {
        var lines = 0
        for (idx, char) in self.enumerated() {
            if char == "\n" {
                lines += 1
                if lines >= count {
                    let index = self.index(self.startIndex, offsetBy: idx)
                    return String(self[..<index])
                }
            }
        }
        return nil
    }
    
    func getLastLines(_ count: Int) -> String? {
        var lines = 0
        for (idx, char) in self.enumerated().reversed() {
            if char == "\n" {
                lines += 1
                if lines >= count {
                    let index = self.index(self.startIndex, offsetBy: idx + 1)
                    return String(self[index...])
                }
            }
        }
        return nil
    }
}
