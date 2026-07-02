import AppKit
import LumiCoreKit
import LumiUI
import SuperLogKit
import HTMLPreviewKit
import LumiPreviewKit
import MagicAlert
import MarkdownKit
import os
import SwiftUI
import EditorService
import StringCatalogKit
import WebKit

/// 预览插件的底部面板内容视图。
///
/// 提供以下功能：
/// - 自动启动 `LumiPreviewHostApp` 子进程，订阅帧流，实时显示预览。
/// - 自动构建：打开 Swift 文件并保存时自动扫描 `#Preview`，编译并加载。
/// - 图片预览：图片文件直接在主进程显示，不启动预览子进程。
public struct EditorPreviewDetailView: View, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.view"
    )
    public nonisolated static let emoji = "👁"
    public nonisolated static let verbose: Bool = false

    // 使用 LumiCore.projectState 替代已移除的 WindowProjectVM
    @EnvironmentObject private var themeVM: AppThemeVM
    @ObservedObject private var viewModel: EditorPreviewViewModel
    private let pluginContext: PluginContext
    @State private var isCleaningCurrentStringCatalog = false
    @State private var isCleaningProjectStringCatalogs = false
    @State private var isConfirmingProjectStringCatalogClean = false
    @State private var isTakingScreenshot = false
    @State private var previewCanvasView: NSView?
    @State private var htmlPreviewWebView: WKWebView?
    @State private var docPreviewWebView: WKWebView?

    @MainActor
    public init(context: PluginContext, viewModel: EditorPreviewViewModel? = nil) {
        self.pluginContext = context
        self.viewModel = viewModel ?? EditorPreviewRuntimeBridge.previewViewModel(context: context)
    }

    @MainActor
    public init(viewModel: EditorPreviewViewModel? = nil) {
        self.init(context: PluginContext(), viewModel: viewModel)
    }

    private var editorService: EditorService? {
        EditorPreviewRuntimeBridge.editorServiceProvider?(pluginContext)
    }

    private var sourceText: String? {
        editorService?.files.content?.string
    }

    private var currentFileURL: URL? {
        editorService?.files.currentFileURL
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            canvasArea
        }
        .onAppear {
            if Self.verbose {
                Self.logger.info("\(self.t)📺 视图出现 — 当前文件=\(currentFileURL?.lastPathComponent ?? "nil")")
            }
            // 订阅 EditorService（幂等，内部有 Combine 订阅，多次调用会重复订阅，所以只调一次）
            if let editorService {
                viewModel.wireEditorService(editorService)
            }
            viewModel.viewDidAppear(fileURL: currentFileURL, sourceText: sourceText)
        }
        .onDisappear {
            viewModel.viewDidDisappear()
        }
        .onChange(of: currentFileURL) { _, newValue in
            if Self.verbose {
                Self.logger.info("\(self.t)📄 currentFileURL 变更 → \(newValue?.lastPathComponent ?? "nil")")
            }
            viewModel.setActiveFile(newValue, sourceText: sourceText)
        }
        .onChange(of: editorService?.files.saveRevision ?? 0) { _, _ in
            if Self.verbose {
                Self.logger.info("\(self.t)💾 saveRevision 变更")
            }
            viewModel.applySaveRevision(sourceText: sourceText)
        }
        .onChange(of: editorService?.files.contentRevision ?? 0) { _, _ in
            viewModel.updateBufferText(sourceText)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            if viewModel.previewMode == .swift {
                entryControls
            } else {
                staticPreviewModeBadge
                markdownTODOBadge
                stringCatalogInfoBadges
            }

            Spacer()

            screenshotButton

            if viewModel.previewMode == .swift {
                buildInfoBadge

                cacheControls

                statusBadge

                entryDebugControls
            } else {
                stringCatalogActionButtons
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .confirmationDialog(
            LumiPluginLocalization.string("Clean all stale String Catalog keys in this project?", bundle: .module),
            isPresented: $isConfirmingProjectStringCatalogClean,
            titleVisibility: .visible
        ) {
            Button(LumiPluginLocalization.string("Clean Project String Catalogs", bundle: .module), role: .destructive) {
                cleanProjectStringCatalogs()
            }
            Button(LumiPluginLocalization.string("Cancel", bundle: .module), role: .cancel) {}
        } message: {
            Text(LumiPluginLocalization.string("This rewrites every .xcstrings file under the current project and removes entries marked as stale.", bundle: .module))
        }
    }

    @ViewBuilder
    private var staticPreviewModeBadge: some View {
        switch viewModel.previewMode {
        case .image:
            Label(LumiPluginLocalization.string("Image Preview", bundle: .module), systemImage: "photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .markdown:
            Label(LumiPluginLocalization.string("Markdown Preview", bundle: .module), systemImage: "doc.richtext")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .stringCatalog:
            Label(LumiPluginLocalization.string("String Catalog Preview", bundle: .module), systemImage: "character.book.closed")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .json:
            Label(LumiPluginLocalization.string("JSON Preview", bundle: .module), systemImage: "curlybraces")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .plist:
            Label(LumiPluginLocalization.string("Plist Preview", bundle: .module), systemImage: "list.bullet.rectangle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .csv:
            Label(LumiPluginLocalization.string("CSV Preview", bundle: .module), systemImage: "tablecells")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .html:
            Label(LumiPluginLocalization.string("HTML Preview", bundle: .module), systemImage: "globe")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .pdf:
            Label(LumiPluginLocalization.string("PDF Preview", bundle: .module), systemImage: "doc.richtext")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .doc:
            Label(LumiPluginLocalization.string("DOC Preview", bundle: .module), systemImage: "doc.text")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .xcassets:
            Label(LumiPluginLocalization.string("Asset Catalog Preview", bundle: .module), systemImage: "folder.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .unsupported(url):
            Label(url?.pathExtension.isEmpty == false ? url!.pathExtension.uppercased() : "File", systemImage: "doc")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .swift:
            EmptyView()
        }
    }

    @ViewBuilder
    private var markdownTODOBadge: some View {
        if case .markdown = viewModel.previewMode,
           let stats = MarkdownTODOScanner.scan(sourceText ?? "") {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.small)
                Text("\(stats.completed)/\(stats.total)")
                    .fontWeight(.semibold)
                Text("(\(stats.percent)%)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .foregroundStyle(.green)
            .lineLimit(1)
            .help(LumiPluginLocalization.string("Markdown TODO completion", bundle: .module))
        }
    }

    /// String Catalog 信息标签（纯展示，放在工具栏左侧）。
    @ViewBuilder
    private var stringCatalogInfoBadges: some View {
        if case .stringCatalog = viewModel.previewMode {
            if let catalog = currentStringCatalog {
                if catalog.staleEntryCount > 0 {
                    Label("\(catalog.staleEntryCount)", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help(LumiPluginLocalization.string("Stale String Catalog keys in the current file", bundle: .module))
                }
            }
        }
    }

    /// String Catalog 操作按钮（放在工具栏右侧）。
    @ViewBuilder
    private var stringCatalogActionButtons: some View {
        if case .stringCatalog = viewModel.previewMode {
            if let catalog = currentStringCatalog {
                if !catalog.translationIssues.isEmpty || catalog.staleEntryCount > 0 {
                    aiFixStringCatalogButton(catalog: catalog)
                }

                Button {
                    cleanCurrentStringCatalog()
                } label: {
                    if isCleaningCurrentStringCatalog {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "trash")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isCleaningCurrentStringCatalog || catalog.staleEntryCount == 0)
                .help(LumiPluginLocalization.string("Clean stale keys in the current String Catalog file", bundle: .module))
            }

            Button {
                isConfirmingProjectStringCatalogClean = true
            } label: {
                if isCleaningProjectStringCatalogs {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "trash.slash")
                }
            }
            .buttonStyle(.borderless)
            .disabled(
                isCleaningProjectStringCatalogs ||
                LumiCore.projectState?.currentProject?.path ?? "".trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .help(LumiPluginLocalization.string("Clean stale keys in every String Catalog file in the current project", bundle: .module))
        }
    }

    @ViewBuilder
    private func aiFixStringCatalogButton(catalog: StringCatalog) -> some View {
        let issueCount = catalog.translationIssues.totalCount + catalog.staleEntryCount
        Button {
            sendFixStringCatalogMessage(catalog: catalog)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkle")
                Text("\(issueCount)")
            }
            .font(.caption)
            .foregroundStyle(.purple)
        }
        .buttonStyle(.borderless)
        .help(LumiPluginLocalization.string("Ask AI to fix String Catalog issues", bundle: .module))
    }

    private static let stringCatalogLLMMaxListedKeys = 15

    private func sendFixStringCatalogMessage(catalog: StringCatalog) {
        guard let fileURL = currentFileURL else { return }

        let issues = catalog.translationIssues
        let untranslated = issues.issues.filter { $0.kind == .untranslated }
        let missing = issues.issues.filter { $0.kind == .missing }
        let staleKeys = catalog.staleEntryKeys
        let hasTranslationIssues = !untranslated.isEmpty || !missing.isEmpty
        let hasStaleEntries = !staleKeys.isEmpty

        var parts: [String] = []
        if hasTranslationIssues && hasStaleEntries {
            parts.append("请修复文件 \(fileURL.path) 的 String Catalog 问题（含翻译问题与废弃条目）。")
        } else if hasStaleEntries {
            parts.append("请处理文件 \(fileURL.path) 中的 String Catalog 废弃条目。")
        } else {
            parts.append("请修复文件 \(fileURL.path) 的翻译问题。")
        }

        if !untranslated.isEmpty {
            let keys = Set(untranslated.map(\.key)).sorted()
            parts.append("以下键值未翻译（翻译值与英文 key 相同）：\(Self.summarizedKeyList(keys))。")
        }

        if !missing.isEmpty {
            let keys = Set(missing.map(\.key)).sorted()
            parts.append("以下键值缺少翻译：\(Self.summarizedKeyList(keys))。")
        }

        if hasStaleEntries {
            if staleKeys.count <= Self.stringCatalogLLMMaxListedKeys {
                parts.append(
                    "以下键值为废弃条目（extractionState 为 stale，代码中可能已无引用），请直接删除，不要翻译：\(Self.summarizedKeyList(staleKeys))。"
                )
            } else {
                parts.append(
                    "当前文件有 \(staleKeys.count) 个废弃条目（extractionState 为 stale，代码中可能已无引用）。示例：\(Self.summarizedKeyList(staleKeys))。请批量删除所有 stale 条目，不要为它们补翻译。"
                )
            }
        }

        if hasTranslationIssues && hasStaleEntries {
            parts.append("请补全翻译（保持格式化字符串占位符不变），并删除所有废弃条目。")
        } else if hasTranslationIssues {
            parts.append("请将所有非源语言的翻译值替换为正确的中/繁体翻译，保持格式化字符串占位符不变。")
        } else {
            parts.append("请删除所有废弃条目。")
        }

        let message = parts.joined(separator: " ")
        EditorPreviewRuntimeBridge.addToChatHandler?(message, pluginContext)
    }

    private static func summarizedKeyList(_ keys: [String]) -> String {
        guard !keys.isEmpty else { return "" }
        if keys.count <= stringCatalogLLMMaxListedKeys {
            return keys.joined(separator: "、")
        }
        let sample = keys.prefix(stringCatalogLLMMaxListedKeys).joined(separator: "、")
        return "\(sample)…（共 \(keys.count) 个，此处仅列举前 \(stringCatalogLLMMaxListedKeys) 个）"
    }

    private var currentStringCatalog: StringCatalog? {
        guard case .stringCatalog = viewModel.previewMode,
              let sourceText else {
            return nil
        }
        return try? StringCatalogParser.parse(sourceText)
    }

    @ViewBuilder
    private var entryControls: some View {
        if viewModel.availablePreviews.count > 1 {
            Picker(
                LumiPluginLocalization.string("Preview", bundle: .module),
                selection: Binding(
                    get: { viewModel.selectedPreviewIndex },
                    set: { viewModel.selectPreview(index: $0) }
                )
            ) {
                ForEach(viewModel.availablePreviews) { preview in
                    Text(preview.title).tag(preview.index)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 180)
            .help(LumiPluginLocalization.string("Choose which #Preview in the current Swift file to build and render.", bundle: .module))
        }
    }

    @ViewBuilder
    private var buildInfoBadge: some View {
        if let info = viewModel.lastBuildInfo {
            Text(buildInfoText(info))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func buildInfoText(_ info: EditorPreviewViewModel.BuildInfo) -> String {
        let mode = info.usedCache
            ? LumiPluginLocalization.string("cache", bundle: .module)
            : LumiPluginLocalization.string("rebuilt", bundle: .module)
        let time = Self.buildTimeFormatter.string(from: info.completedAt)
        return "\(mode) · \(time) · \(info.previewCount) preview(s)"
    }

    @ViewBuilder
    private var cacheControls: some View {
        let summary = viewModel.cacheSummary
        if !summary.isEmpty {
            HStack(spacing: 4) {
                Label(
                    "\(LumiPluginLocalization.string("cache", bundle: .module)) · \(summary.formattedByteCount)",
                    systemImage: "externaldrive"
                )
                .labelStyle(.titleAndIcon)

                Button {
                    viewModel.purgeBuildCaches()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(LumiPluginLocalization.string("Clear Inline Preview build cache", bundle: .module))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var entryDebugControls: some View {
        if canRequestEntryDebugState {
            Button {
                viewModel.requestEntryDebugState()
            } label: {
                if viewModel.isRequestingEntryDebugState {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "stethoscope")
                }
            }
            .buttonStyle(.borderless)
            .help(LumiPluginLocalization.string("Refresh entry debug state", bundle: .module))
        }
    }

    private var canRequestEntryDebugState: Bool {
        guard viewModel.status == .running else { return false }
        if case .loaded = viewModel.entryStatus {
            return true
        }
        return false
    }

    // MARK: - Screenshot

    @ViewBuilder
    private var screenshotButton: some View {
        Button {
            takeScreenshot()
        } label: {
            if isTakingScreenshot {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "camera.viewfinder")
            }
        }
        .buttonStyle(.borderless)
        .disabled(canTakeScreenshot == false)
        .help(LumiPluginLocalization.string("Screenshot preview canvas", bundle: .module))
    }

    /// 当前是否可以截图：swift 预览正在运行且已加载 entry，或非 swift 静态预览（image、markdown 等）。
    /// 字符串目录格式不显示截图按钮。
    private var canTakeScreenshot: Bool {
        switch viewModel.previewMode {
        case .swift:
            return viewModel.status == .running && viewModel.currentFrame != nil
        case .stringCatalog, .unsupported, .xcassets:
            return false
        default:
            return true
        }
    }

    private func takeScreenshot() {
        guard !isTakingScreenshot else { return }
        isTakingScreenshot = true

        // 对于 SVG 图片，直接复制原文件到 Downloads，而不是截图转 PNG（否则会得到空白图片）
        if case let .image(url) = viewModel.previewMode,
           EditorPreviewExportPolicy.shouldCopyOriginalImage(for: url) {
            copyOriginalFileToDownloads(url)
            return
        }

        switch viewModel.previewMode {
        case .swift:
            takeSwiftScreenshot()
        default:
            takeStaticScreenshot()
        }
    }

    private func copyOriginalFileToDownloads(_ sourceURL: URL) {
        isTakingScreenshot = false

        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            alert_warning(LumiPluginLocalization.string("Failed to save file.", bundle: .module))
            return
        }

        let finalURL = EditorPreviewExportPolicy.uniqueDestinationURL(
            for: sourceURL,
            in: downloadsURL,
            fileExists: { FileManager.default.fileExists(atPath: $0.path) }
        )

        do {
            try FileManager.default.copyItem(at: sourceURL, to: finalURL)

            alert_success(
                String(
                    format: LumiPluginLocalization.string("File saved to Downloads: %@", bundle: .module),
                    finalURL.lastPathComponent
                )
            )

            if Self.verbose {
                Self.logger.info("\(self.t)📎 文件已复制至：\(finalURL.path)")
            }
        } catch {
            alert_error(
                String(
                    format: LumiPluginLocalization.string("Failed to save file: %@", bundle: .module),
                    error.localizedDescription
                )
            )
        }
    }

    private func takeSwiftScreenshot() {
        // 获取当前 window 的 contentView，从中找到 PreviewSurfaceView
        guard let window = NSApp.keyWindow else {
            isTakingScreenshot = false
            return
        }

        let image = viewModel.takeScreenshot(from: window.contentView)
        isTakingScreenshot = false

        guard let image else {
            alert_warning(LumiPluginLocalization.string("Failed to capture preview screenshot.", bundle: .module))
            return
        }

        saveScreenshotToDesktop(image)
    }

    private func takeStaticScreenshot() {
        if case .html = viewModel.previewMode,
           let webView = htmlPreviewWebView {
            takeHTMLScreenshot(webView)
            return
        }

        // DOC 预览需要特殊处理：使用 WKWebView 渲染，
        // cacheDisplay 无法捕获 WKWebView 内容，需要用 HTMLScreenshotter
        if case .doc = viewModel.previewMode,
           let webView = docPreviewWebView {
            takeHTMLScreenshot(webView)
            return
        }

        guard let canvasView = previewCanvasView else {
            isTakingScreenshot = false
            alert_warning(LumiPluginLocalization.string("Failed to capture preview screenshot.", bundle: .module))
            return
        }

        guard let image = renderImage(from: canvasView) else {
            isTakingScreenshot = false
            alert_warning(LumiPluginLocalization.string("Failed to capture preview screenshot.", bundle: .module))
            return
        }

        isTakingScreenshot = false
        saveScreenshotToDesktop(image)
    }

    @MainActor
    private func takeHTMLScreenshot(_ webView: WKWebView) {
        Task {
            do {
                let image = try await HTMLScreenshotter.capture(webView)
                isTakingScreenshot = false
                saveScreenshotToDesktop(image)
            } catch {
                isTakingScreenshot = false
                Self.logger.error("\(Self.t)📸 HTML 截图失败：\(error.localizedDescription)")
                alert_warning(LumiPluginLocalization.string("Failed to capture preview screenshot.", bundle: .module))
            }
        }
    }

    private func renderImage(from view: NSView) -> NSImage? {
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }

        view.cacheDisplay(in: bounds, to: bitmapRep)
        let image = NSImage()
        image.addRepresentation(bitmapRep)
        image.size = bounds.size
        return image
    }

    private func saveScreenshotToDesktop(_ image: NSImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard let downloadsURL,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            alert_warning(LumiPluginLocalization.string("Failed to capture preview screenshot.", bundle: .module))
            return
        }

        let fileName = "Preview_\(timestamp).png"
        let sourceURL = downloadsURL.appendingPathComponent(fileName)
        let fileURL = EditorPreviewExportPolicy.uniqueDestinationURL(
            for: sourceURL,
            in: downloadsURL,
            fileExists: { FileManager.default.fileExists(atPath: $0.path) }
        )

        do {
            try pngData.write(to: fileURL)

            // 同时复制到剪贴板
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])

            alert_success(
                String(
                    format: LumiPluginLocalization.string("Screenshot saved to Downloads and copied to clipboard: %@", bundle: .module),
                    fileURL.lastPathComponent
                )
            )

            if Self.verbose {
                Self.logger.info("\(self.t)📸 截图已保存至：\(fileURL.path)")
            }
        } catch {
            alert_error(
                String(
                    format: LumiPluginLocalization.string("Failed to save screenshot: %@", bundle: .module),
                    error.localizedDescription
                )
            )
        }
    }

    private static let buildTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    private func cleanCurrentStringCatalog() {
        guard !isCleaningCurrentStringCatalog else { return }
        isCleaningCurrentStringCatalog = true
        defer { isCleaningCurrentStringCatalog = false }

        do {
            guard let editorService else {
                alert_warning(LumiPluginLocalization.string("Editor service is not available.", bundle: .module))
                return
            }
            let removedCount = try viewModel.cleanCurrentStringCatalog(
                fileURL: currentFileURL,
                sourceText: sourceText,
                editorService: editorService
            )
            if removedCount > 0 {
                alert_success(
                    String(
                        format: LumiPluginLocalization.string("Removed %d stale String Catalog key(s).", bundle: .module),
                        removedCount
                    )
                )
            } else {
                alert_info(LumiPluginLocalization.string("No stale String Catalog keys found.", bundle: .module))
            }
        } catch {
            alert_error(
                String(
                    format: LumiPluginLocalization.string("Failed to clean String Catalog: %@", bundle: .module),
                    error.localizedDescription
                )
            )
        }
    }

    private func cleanProjectStringCatalogs() {
        guard !isCleaningProjectStringCatalogs else { return }
        let projectRootPath = LumiCore.projectState?.currentProject?.path ?? "".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectRootPath.isEmpty else {
            alert_warning(LumiPluginLocalization.string("Select a project before cleaning String Catalogs.", bundle: .module))
            return
        }
        guard let editorService else {
            alert_warning(LumiPluginLocalization.string("Editor service is not available.", bundle: .module))
            return
        }

        isCleaningProjectStringCatalogs = true
        Task {
            do {
                let summary = try await viewModel.cleanProjectStringCatalogs(
                    projectRootPath: projectRootPath,
                    currentFileURL: currentFileURL,
                    currentSourceText: sourceText,
                    editorService: editorService
                )
                isCleaningProjectStringCatalogs = false

                if summary.removedEntryCount > 0 {
                    alert_success(
                        String(
                            format: LumiPluginLocalization.string("Removed %d stale key(s) from %d String Catalog file(s).", bundle: .module),
                            summary.removedEntryCount,
                            summary.changedFileCount
                        )
                    )
                } else {
                    alert_info(
                        String(
                            format: LumiPluginLocalization.string("Scanned %d String Catalog file(s); no stale keys found.", bundle: .module),
                            summary.scannedFileCount
                        )
                    )
                }
            } catch {
                isCleaningProjectStringCatalogs = false
                alert_error(
                    String(
                        format: LumiPluginLocalization.string("Failed to clean project String Catalogs: %@", bundle: .module),
                        error.localizedDescription
                    )
                )
            }
        }
    }

    private func removeStaleStringCatalogEntry(key: String) {
        guard let editorService else {
            alert_warning(LumiPluginLocalization.string("Editor service is not available.", bundle: .module))
            return
        }

        do {
            let removed = try viewModel.removeStaleStringCatalogEntry(
                key: key,
                fileURL: currentFileURL,
                sourceText: sourceText,
                editorService: editorService
            )
            if removed {
                alert_success(
                    String(
                        format: LumiPluginLocalization.string("Removed %d stale String Catalog key(s).", bundle: .module),
                        1
                    )
                )
            }
        } catch {
            alert_error(
                String(
                    format: LumiPluginLocalization.string("Failed to clean String Catalog: %@", bundle: .module),
                    error.localizedDescription
                )
            )
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch viewModel.status {
        case .idle:
            EmptyView()
        case .warming:
            Text(LumiPluginLocalization.string("warming", bundle: .module)).font(.caption).foregroundStyle(.orange)
        case .ready:
            Text(LumiPluginLocalization.string("ready", bundle: .module)).font(.caption).foregroundStyle(.secondary)
        case .starting:
            Text(LumiPluginLocalization.string("starting", bundle: .module)).font(.caption).foregroundStyle(.orange)
        case .running:
            Text(LumiPluginLocalization.string("running · \(viewModel.policy.rawValue)", bundle: .module)).font(.caption).foregroundStyle(.green)
        case .stopping:
            Text(LumiPluginLocalization.string("stopping", bundle: .module)).font(.caption).foregroundStyle(.orange)
        case let .failed(message):
            Text(LumiPluginLocalization.string("failed: \(message)", bundle: .module))
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Canvas

    @ViewBuilder
    private var canvasArea: some View {
        Group {
            switch viewModel.previewMode {
            case .swift:
                swiftPreviewCanvas
            case let .image(url):
                EditorPreviewImageView(fileURL: url)
            case .markdown:
                EditorPreviewMarkdownView(
                    markdown: sourceText ?? "",
                    fileURL: currentFileURL,
                    editorService: editorService,
                    pluginContext: pluginContext
                )
                    .environmentObject(themeVM)
            case .stringCatalog:
                EditorPreviewStringCatalogContainer(
                    sourceText: sourceText ?? "",
                    onRemoveStaleEntry: removeStaleStringCatalogEntry
                )
                    .environmentObject(themeVM)
            case .json:
                EditorPreviewJSONView(jsonText: sourceText ?? "")
                    .environmentObject(themeVM)
            case .plist:
                EditorPreviewPlistView(plistText: sourceText ?? "")
                    .environmentObject(themeVM)
            case let .csv(url):
                EditorPreviewCSVView(csvText: sourceText ?? "", fileURL: url)
                    .environmentObject(themeVM)
            case let .html(url):
                HTMLPreviewView(
                    htmlText: sourceText ?? "",
                    fileURL: url,
                    onWebViewResolved: { webView in
                        htmlPreviewWebView = webView
                    }
                )
            case let .pdf(url):
                EditorPreviewPDFView(fileURL: url)
                    .environmentObject(themeVM)
            case let .doc(url):
                EditorPreviewDOCView(
                    fileURL: url,
                    onWebViewResolved: { webView in
                        docPreviewWebView = webView
                    }
                )
                    .environmentObject(themeVM)
            case let .xcassets(url):
                EditorPreviewXCAssetsView(xcassetsURL: url)
                    .environmentObject(themeVM)
            case let .unsupported(url):
                unsupportedPreview(url: url)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            EditorPreviewCanvasAccessor { view in
                previewCanvasView = view
            }
        )
    }

    @ViewBuilder
    private var swiftPreviewCanvas: some View {
        let hasFrame = viewModel.currentFrame != nil
        GeometryReader { proxy in
            ZStack {
                PreviewBoardGrid()

                if !hasFrame && !isEntryFailed {
                    VStack(spacing: 12) {
                        if viewModel.entryStatus == .noPreview, currentFileURL?.pathExtension == "swift" {
                            Image(systemName: "bolt.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text(LumiPluginLocalization.string("No #Preview in the current Swift file.", bundle: .module))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        } else {
                            Image(systemName: "rectangle.dashed")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text(LumiPluginLocalization.string("Open a Swift file with a `#Preview`; Inline Preview starts automatically and refreshes when you save.", bundle: .module))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                }

                LumiPreviewFacade.PreviewSurfaceCanvas(
                    surfaceID: viewModel.currentFrame?.surfaceID,
                    isInteractive: viewModel.isInteractive,
                    cursorShape: viewModel.cursorShape,
                    onSizeChange: { size, scale in
                        viewModel.canvasDidResize(size, scale: scale)
                    },
                    onInputEvent: { event in
                        viewModel.forwardInputEvent(event)
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(hasFrame ? Color.clear : Color.black.opacity(0.01))

                if let failure = entryFailure {
                    PreviewFailureView(
                        failure: failure,
                        buildLogURL: viewModel.lastBuildLogURL,
                        onRetry: { viewModel.retryBuild() },
                        onAskAI: { sendPreviewFailureToChat(failure: failure) }
                    )
                }

                if let debugState = viewModel.entryDebugState, !debugState.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            EditorPreviewDebugStateView(state: debugState)
                                .padding(16)
                        }
                        Spacer()
                    }
                }

                if let file = buildingFileName {
                    PreviewBuildingView(fileName: file)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isEntryFailed: Bool {
        if case .failed = viewModel.entryStatus {
            return true
        }
        return false
    }

    private var entryFailure: EditorPreviewViewModel.EntryFailure? {
        if case let .failed(failure) = viewModel.entryStatus {
            return failure
        }
        return nil
    }

    private func sendPreviewFailureToChat(failure: EditorPreviewViewModel.EntryFailure) {
        let prompt = LumiPluginLocalization.string(
            "Please analyze whether this Swift #Preview failure is caused by a Lumi bug or a problem in the current project, and explain how to fix it:",
            bundle: .module
        )

        var lines = [prompt, ""]

        if let fileURL = currentFileURL {
            lines.append("File: \(fileURL.path)")
        }

        lines.append("Failure: \(failure.title) (\(failure.kind.rawValue))")

        if let preview = viewModel.availablePreviews.first(where: { $0.index == viewModel.selectedPreviewIndex }) {
            lines.append("Preview: \(preview.title) (index \(preview.index))")
        } else if !viewModel.availablePreviews.isEmpty {
            lines.append("Preview index: \(viewModel.selectedPreviewIndex)")
        }

        lines.append("")
        lines.append(failure.message)

        if let buildLogURL = viewModel.lastBuildLogURL {
            lines.append("")
            lines.append("Build log: \(buildLogURL.path)")
        }

        EditorPreviewRuntimeBridge.addToChatHandler?(lines.joined(separator: "\n"), pluginContext)
    }

    private var buildingFileName: String? {
        if case let .building(file) = viewModel.entryStatus {
            return file
        }
        return nil
    }

    private func unsupportedPreview(url: URL?) -> some View {
        ZStack {
            PreviewBoardGrid()
            VStack(spacing: 12) {
                Image(systemName: "doc")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(url == nil
                     ? LumiPluginLocalization.string("Open a Swift file with a `#Preview`, an image, Markdown, JSON, or String Catalog file to preview it here.", bundle: .module)
                     : LumiPluginLocalization.string("This file type is not supported by Inline Preview yet.", bundle: .module))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

private struct EditorPreviewCanvasAccessor: NSViewRepresentable {
    public let onResolve: (NSView) -> Void

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        DispatchQueue.main.async {
            onResolve(view.superview ?? view)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.superview ?? nsView)
        }
    }
}

private struct EditorPreviewDebugStateView: View {
    public let state: String

    @State private var isExpanded = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .foregroundStyle(.blue)
                Text(LumiPluginLocalization.string("Entry debug state", bundle: .module))
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.borderless)
                .help(LumiPluginLocalization.string("Show entry debug state", bundle: .module))
            }

            if isExpanded {
                ScrollView {
                    Text(state)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 180)
                .background(Color.black.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(state)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.18), lineWidth: 1)
        )
        .frame(width: 360)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

struct MarkdownTODOStats: Equatable {
    public let total: Int
    public let completed: Int

    public var ratio: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    public var percent: Int {
        Int((ratio * 100).rounded())
    }
}

enum MarkdownTODOScanner {
    public static func scan(_ markdown: String) -> MarkdownTODOStats? {
        var total = 0
        var completed = 0
        var fenceMarker: String?

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }

            if let activeFenceMarker = fenceMarker {
                if trimmed.hasPrefix(activeFenceMarker) {
                    fenceMarker = nil
                }
                continue
            }

            if let openingFenceMarker = openingFenceMarker(in: trimmed) {
                fenceMarker = openingFenceMarker
                continue
            }

            if let isCompleted = taskListItemCompletion(in: trimmed) {
                total += 1
                if isCompleted {
                    completed += 1
                }
            }
        }

        guard total > 0 else { return nil }
        return MarkdownTODOStats(total: total, completed: completed)
    }

    private static func openingFenceMarker(in trimmedLine: Substring) -> String? {
        guard let first = trimmedLine.first, first == "`" || first == "~" else {
            return nil
        }

        let markerLength = trimmedLine.prefix { $0 == first }.count
        guard markerLength >= 3 else { return nil }
        return String(repeating: String(first), count: markerLength)
    }

    private static func taskListItemCompletion(in trimmedLine: Substring) -> Bool? {
        guard let markerEnd = listMarkerEnd(in: trimmedLine) else {
            return nil
        }

        var remainder = trimmedLine[markerEnd...]
        guard let separator = remainder.first, separator == " " || separator == "\t" else {
            return nil
        }

        remainder = remainder.drop { $0 == " " || $0 == "\t" }
        if remainder.hasPrefix("[ ]") {
            return false
        }
        if remainder.hasPrefix("[x]") || remainder.hasPrefix("[X]") {
            return true
        }
        return nil
    }

    private static func listMarkerEnd(in trimmedLine: Substring) -> Substring.Index? {
        guard let first = trimmedLine.first else { return nil }
        if first == "-" || first == "*" || first == "+" {
            return trimmedLine.index(after: trimmedLine.startIndex)
        }

        guard first.isNumber else { return nil }

        var cursor = trimmedLine.startIndex
        while cursor < trimmedLine.endIndex, trimmedLine[cursor].isNumber {
            cursor = trimmedLine.index(after: cursor)
        }

        guard cursor < trimmedLine.endIndex, trimmedLine[cursor] == "." || trimmedLine[cursor] == ")" else {
            return nil
        }

        return trimmedLine.index(after: cursor)
    }
}

private struct MarkdownTOCHeading: Identifiable, Hashable {
    public let id: String
    public let level: Int
    public let title: String
    public let lineNumber: Int
}

enum EditorPreviewExportPolicy {
    static func shouldCopyOriginalImage(for url: URL) -> Bool {
        url.pathExtension.localizedCaseInsensitiveCompare("svg") == .orderedSame
    }

    static func uniqueDestinationURL(
        for sourceURL: URL,
        in directoryURL: URL,
        fileExists: (URL) -> Bool
    ) -> URL {
        let fileName = sourceURL.lastPathComponent
        var destinationURL = directoryURL.appendingPathComponent(fileName)
        var counter = 1

        while fileExists(destinationURL) {
            let name = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            let numberedName = ext.isEmpty
                ? "\(name) (\(counter))"
                : "\(name) (\(counter)).\(ext)"
            destinationURL = directoryURL.appendingPathComponent(numberedName)
            counter += 1
        }

        return destinationURL
    }
}

private struct MarkdownTOCSection: Identifiable {
    public let id: String
    public let markdown: String
}

private enum MarkdownTOCScanner {
    public static func scan(_ markdown: String) -> (headings: [MarkdownTOCHeading], sections: [MarkdownTOCSection]) {
        let lines = markdown.components(separatedBy: .newlines)
        var headings: [MarkdownTOCHeading] = []
        var sectionStarts: [(lineIndex: Int, heading: MarkdownTOCHeading)] = []
        var isInFence = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                isInFence.toggle()
                continue
            }
            guard !isInFence, let parsed = parseATXHeading(trimmed) else { continue }

            let heading = MarkdownTOCHeading(
                id: "markdown-heading-\(index)",
                level: parsed.level,
                title: parsed.title,
                lineNumber: index
            )
            headings.append(heading)
            sectionStarts.append((index, heading))
        }

        guard !sectionStarts.isEmpty else {
            return (
                headings: [],
                sections: [.init(id: "markdown-section-root", markdown: markdown)]
            )
        }

        var sections: [MarkdownTOCSection] = []
        if sectionStarts[0].lineIndex > 0 {
            let prefix = lines[..<sectionStarts[0].lineIndex].joined(separator: "\n")
            if !prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sections.append(.init(id: "markdown-section-root", markdown: prefix))
            }
        }

        for index in sectionStarts.indices {
            let start = sectionStarts[index].lineIndex
            let end = index + 1 < sectionStarts.count ? sectionStarts[index + 1].lineIndex : lines.count
            let sectionMarkdown = lines[start..<end].joined(separator: "\n")
            sections.append(.init(id: sectionStarts[index].heading.id, markdown: sectionMarkdown))
        }

        return (headings, sections)
    }

    private static func parseATXHeading(_ trimmedLine: String) -> (level: Int, title: String)? {
        guard trimmedLine.hasPrefix("#") else { return nil }
        let hashes = trimmedLine.prefix { $0 == "#" }
        let level = hashes.count
        guard (1...6).contains(level) else { return nil }

        let remainder = trimmedLine.dropFirst(level)
        guard remainder.first == " " || remainder.first == "\t" else { return nil }

        let rawTitle = remainder
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(
                of: #"\s+#+\s*$"#,
                with: "",
                options: .regularExpression
            )
        guard !rawTitle.isEmpty else { return nil }
        return (level, rawTitle)
    }
}

private struct EditorPreviewMarkdownView: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    public let markdown: String
    public let fileURL: URL?
    public let editorService: EditorService?
    public let pluginContext: PluginContext
    @State private var scrollToID: String?

    private var toc: (headings: [MarkdownTOCHeading], sections: [MarkdownTOCSection]) {
        MarkdownTOCScanner.scan(markdown)
    }

    public var body: some View {
        let scannedTOC = toc
        Group {
            if markdown.isEmpty {
                emptyMarkdownView
            } else if scannedTOC.headings.isEmpty {
                markdownScrollView(sections: scannedTOC.sections)
            } else {
                HStack(spacing: 0) {
                    markdownTOCSidebar(headings: scannedTOC.headings)
                    Divider()
                    ScrollViewReader { proxy in
                        markdownScrollView(sections: scannedTOC.sections)
                            .onChange(of: scrollToID) { _, newValue in
                                if let id = newValue {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        proxy.scrollTo(id, anchor: .top)
                                    }
                                    scrollToID = nil
                                }
                            }
                    }
                }
            }
        }
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    private var emptyMarkdownView: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(LumiPluginLocalization.string("No Markdown content to preview.", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
            .padding(24)
        }
    }

    private func markdownScrollView(sections: [MarkdownTOCSection]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    MarkdownBlockRenderer(
                        markdown: section.markdown,
                        theme: previewTheme
                    )
                    .environment(\.codeHighlightProvider, nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(section.id)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func markdownTOCSidebar(
        headings: [MarkdownTOCHeading]
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: LumiPluginLocalization.string("TOC", bundle: .module))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                ForEach(headings) { heading in
                    Button {
                        scrollToID = heading.id
                    } label: {
                        Text(heading.title)
                            .font(.system(size: 12, weight: heading.level <= 2 ? .semibold : .regular))
                            .foregroundStyle(themeVM.activeChromeTheme.workspaceTextColor())
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                            .padding(.leading, CGFloat(max(0, heading.level - 1)) * 10)
                            .padding(.trailing, 8)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .help(heading.title)
                    .draggable(makeDragContent(for: heading))
                    .contextMenu {
                        Button {
                            addToChat(heading: heading)
                        } label: {
                            Label(LumiPluginLocalization.string("Add to Chat", bundle: .module), systemImage: "bubble.left")
                        }
                        Divider()
                        Button(role: .destructive) {
                            deleteHeadingAndContent(heading: heading)
                        } label: {
                            Label(LumiPluginLocalization.string("Delete", bundle: .module), systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.vertical, 14)
        }
        .frame(width: 220)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor().opacity(0.72))
    }

    private func makeDragContent(for heading: MarkdownTOCHeading) -> String {
        guard let fileURL else {
            return heading.title
        }
        // 行号从 0 开始，显示时 +1
        let lineNumber = heading.lineNumber + 1
        return "\(fileURL.path):\(lineNumber) \(heading.title)"
    }

    private func addToChat(heading: MarkdownTOCHeading) {
        let text = makeDragContent(for: heading)
        EditorPreviewRuntimeBridge.addToChatHandler?(text, pluginContext)
    }

    /// 从 markdown 源文件中删除指定标题及其子内容（直到下一个同级或更高级标题，或文件末尾）。
    private func deleteHeadingAndContent(heading: MarkdownTOCHeading) {
        guard let editorService else { return }

        let lines = markdown.components(separatedBy: .newlines)
        let startLine = heading.lineNumber

        // 找到删除范围的结束行：下一个 level <= heading.level 的标题，或文件末尾
        var endLine = lines.count
        var inFence = false
        for i in (startLine + 1)..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                continue
            }
            guard !inFence, let parsed = parseATXHeadingQuick(trimmed) else { continue }
            if parsed <= heading.level {
                endLine = i
                break
            }
        }

        // 计算要删除的文本范围
        let prefix = lines[..<startLine].joined(separator: "\n")
        let suffix = lines[endLine...].joined(separator: "\n")
        var newContent = prefix
        if !suffix.isEmpty {
            // 如果 prefix 末尾有换行且 suffix 开头有换行，避免多余空行
            if prefix.hasSuffix("\n") || (!newContent.isEmpty && newContent.last != "\n") {
                newContent += "\n"
            }
            newContent += suffix
        }

        // 清理多余空行（超过两个连续换行合并为两个）
        newContent = newContent.replacingOccurrences(
            of: "\n{4,}",
            with: "\n\n\n",
            options: .regularExpression
        )

        // 替换编辑器内容
        _ = editorService.files.replaceCurrentDocumentText(newContent, reason: "markdown_delete_heading")
        editorService.files.saveNow()
    }

    /// 快速解析 ATX 标题，只返回 level
    private func parseATXHeadingQuick(_ trimmedLine: String) -> Int? {
        guard trimmedLine.hasPrefix("#") else { return nil }
        let hashes = trimmedLine.prefix { $0 == "#" }
        let level = hashes.count
        guard (1...6).contains(level) else { return nil }
        let remainder = trimmedLine.dropFirst(level)
        guard remainder.first == " " || remainder.first == "\t" else { return nil }
        return level
    }

    private var previewTheme: MarkdownTheme {
        let theme = themeVM.activeChromeTheme
        return MarkdownTheme(
            headingFont: { level in
                switch level {
                case 1: return .system(size: 26, weight: .bold)
                case 2: return .system(size: 22, weight: .semibold)
                case 3: return .system(size: 18, weight: .semibold)
                default: return .system(size: 16, weight: .semibold)
                }
            },
            bodyFont: .system(size: 15, weight: .regular),
            codeFont: .system(size: 13, weight: .regular, design: .monospaced),
            blockSpacing: 12,
            listItemSpacing: 5,
            codeBlockBackground: Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.06),
            quoteBorderColor: Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.4),
            tableHeaderBackground: Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.1),
            showLanguageLabel: true,
            textColor: theme.workspaceTextColor(),
            secondaryTextColor: theme.workspaceSecondaryTextColor()
        )
    }

}

private struct EditorPreviewStringCatalogContainer: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    public let sourceText: String
    public var onRemoveStaleEntry: ((String) -> Void)?

    public var body: some View {
        Group {
            if sourceText.isEmpty {
                messageView(
                    systemImage: "character.book.closed",
                    text: LumiPluginLocalization.string("No String Catalog content to preview.", bundle: .module)
                )
            } else {
                switch parseResult {
                case let .success(catalog):
                    EditorPreviewStringCatalogView(
                        catalog: catalog,
                        onRemoveStaleEntry: onRemoveStaleEntry
                    )
                        .environmentObject(themeVM)
                case let .failure(error):
                    messageView(
                        systemImage: "exclamationmark.triangle",
                        text: String(
                            format: LumiPluginLocalization.string("Failed to load string catalog: %@", bundle: .module),
                            error.localizedDescription
                        )
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    private var parseResult: Result<StringCatalog, Error> {
        Result {
            try StringCatalogParser.parse(sourceText)
        }
    }

    private func messageView(systemImage: String, text: String) -> some View {
        ZStack {
            PreviewBoardGrid()
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }
}

private struct EditorPreviewStringCatalogView: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    public let catalog: StringCatalog
    public var onRemoveStaleEntry: ((String) -> Void)?
    @State private var selectedLanguageID: String?

    private var selectedLanguage: StringCatalog.Language {
        if let selectedLanguageID,
           let language = catalog.languages.first(where: { $0.id == selectedLanguageID }) {
            return language
        }
        return catalog.languages.first(where: { !$0.isSourceLanguage })
            ?? catalog.languages.first
            ?? StringCatalog.Language(
                id: catalog.sourceLanguage,
                displayName: catalog.sourceLanguage,
                completion: 0,
                translatedCount: 0,
                totalCount: 0,
                isSourceLanguage: true
            )
    }

    private var sourceLanguage: StringCatalog.Language {
        catalog.languages.first(where: { $0.id == catalog.sourceLanguage }) ?? selectedLanguage
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            languageSidebar
                .frame(width: 240)
            Divider()
            catalogTable
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
        .onAppear {
            if selectedLanguageID == nil {
                selectedLanguageID = selectedLanguage.id
            }
        }
        .onChange(of: catalog.languages) { _, _ in
            guard let selectedLanguageID,
                  catalog.languages.contains(where: { $0.id == selectedLanguageID }) else {
                self.selectedLanguageID = selectedLanguage.id
                return
            }
        }
    }

    private var languageSidebar: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(catalog.languages) { language in
                    Button {
                        selectedLanguageID = language.id
                    } label: {
                        languageRow(language)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func languageRow(_ language: StringCatalog.Language) -> some View {
        let isSelected = selectedLanguage.id == language.id
        let textColor = isSelected ? Color.white : themeVM.activeChromeTheme.workspaceTextColor()
        let secondaryColor = isSelected ? Color.white.opacity(0.86) : themeVM.activeChromeTheme.workspaceSecondaryTextColor()

        return HStack(spacing: 8) {
            Text(languageBadge(for: language.id))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? Color.accentColor : Color.white)
                .frame(width: 28, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white : Color.adaptive(light: "5D768A", dark: "4D6C82"))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(language.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                if language.isSourceLanguage {
                    Text(LumiPluginLocalization.string("Default Localization", bundle: .module))
                        .font(.system(size: 11))
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if !language.isSourceLanguage {
                Text(progressText(for: language))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(secondaryColor)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }

    private var catalogTable: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(catalog.entries) { row in
                        catalogRow(row)
                    }
                } header: {
                    tableHeader
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            headerCell(LumiPluginLocalization.string("Key", bundle: .module), width: 340)
            headerCell(sourceColumnTitle, width: 360)
            if selectedLanguage.id != sourceLanguage.id {
                headerCell(selectedLanguageColumnTitle, width: 360)
            }
        }
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func catalogRow(_ row: StringCatalog.Entry) -> some View {
        HStack(alignment: .top, spacing: 0) {
            valueCell(text: row.key, width: 340, isMissing: false)
            valueCell(
                text: row.valuesByLanguage[sourceLanguage.id]?.text ?? row.key,
                width: 360,
                isMissing: row.valuesByLanguage[sourceLanguage.id]?.text == nil
            )
            if selectedLanguage.id != sourceLanguage.id {
                valueCell(
                    text: row.valuesByLanguage[selectedLanguage.id]?.text ?? row.key,
                    width: 360,
                    isMissing: row.valuesByLanguage[selectedLanguage.id]?.text == nil
                )
            }
        }
        .background(rowBackground(for: row))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .contentShape(Rectangle())
        .contextMenu {
            if row.extractionState == "stale", let onRemoveStaleEntry {
                Button(role: .destructive) {
                    onRemoveStaleEntry(row.key)
                } label: {
                    Label(
                        LumiPluginLocalization.string("Remove Stale Key", bundle: .module),
                        systemImage: "trash"
                    )
                }
            }
        }
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(themeVM.activeChromeTheme.workspaceTextColor())
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .overlay(alignment: .trailing) {
                Divider()
            }
    }

    private func valueCell(text: String, width: CGFloat, isMissing: Bool) -> some View {
        EditorInlineHighlightedStringCatalogText(text: text, isMissing: isMissing)
            .foregroundColor(isMissing ? themeVM.activeChromeTheme.workspaceSecondaryTextColor().opacity(0.58) : themeVM.activeChromeTheme.workspaceTextColor())
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .overlay(alignment: .trailing) {
                Divider()
            }
    }

    private func rowBackground(for row: StringCatalog.Entry) -> Color {
        row.extractionState == "stale"
            ? Color.yellow.opacity(0.10)
            : Color.clear
    }

    private var sourceColumnTitle: String {
        String(
            format: LumiPluginLocalization.string("Default Localization (%@)", bundle: .module),
            sourceLanguage.id
        )
    }

    private var selectedLanguageColumnTitle: String {
        "\(selectedLanguage.displayName) (\(selectedLanguage.id))"
    }

    private func progressText(for language: StringCatalog.Language) -> String {
        "\(Int((language.completion * 100).rounded()))%"
    }

    private func languageBadge(for languageID: String) -> String {
        let normalized = languageID.replacingOccurrences(of: "_", with: "-")
        let parts = normalized.split(separator: "-")
        if normalized.hasPrefix("zh-Hans") || normalized == "zh" {
            return "简"
        }
        if normalized.hasPrefix("zh-Hant") || normalized.hasPrefix("zh-HK") || normalized.hasPrefix("zh-TW") {
            return "中"
        }
        return String(parts.first?.prefix(2).uppercased() ?? normalized.prefix(2).uppercased())
    }
}

private struct EditorInlineHighlightedStringCatalogText: View {
    public let text: String
    public let isMissing: Bool

    public var body: some View {
        Text(attributedText)
            .font(.system(size: 14))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedText: AttributedString {
        var result = AttributedString(text)
        guard !isMissing else {
            return result
        }

        for placeholder in StringCatalogPlaceholderScanner.placeholders(in: text) {
            let range = placeholder.range
            if let attributedRange = Range(range, in: result) {
                result[attributedRange].backgroundColor = Color.accentColor.opacity(0.28)
                result[attributedRange].foregroundColor = Color.accentColor
            }
        }
        return result
    }
}

private struct EditorPreviewImageView: View {
    public let fileURL: URL

    @State private var image: NSImage?
    @State private var loadError: String?

    public var body: some View {
        ZStack {
            PreviewBoardGrid()

            if let image {
                imageContent(image)
            } else if let loadError {
                messageView(systemImage: "exclamationmark.triangle", text: loadError)
            } else {
                ProgressView()
            }
        }
        .task(id: fileURL) {
            loadImage()
        }
    }

    private func imageContent(_ image: NSImage) -> some View {
        GeometryReader { geometry in
            let fitted = fittedSize(
                original: image.size,
                container: CGSize(width: geometry.size.width - 40, height: geometry.size.height - 84)
            )

            VStack(spacing: 14) {
                Spacer(minLength: 0)

                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: fitted.width, height: fitted.height)
                    .background(checkerboardBackground.clipShape(RoundedRectangle(cornerRadius: 6)))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.secondary.opacity(0.18), lineWidth: 1)
                    )

                HStack(spacing: 14) {
                    Label("\(Int(image.size.width)) x \(Int(image.size.height)) pt", systemImage: "arrow.up.left.and.arrow.down.right")
                    if let fileSizeString {
                        Label(fileSizeString, systemImage: "doc")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        }
    }

    private func messageView(systemImage: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private var checkerboardBackground: some View {
        GeometryReader { geometry in
            let tileSize: CGFloat = 12
            let cols = max(1, Int(ceil(geometry.size.width / tileSize)))
            let rows = max(1, Int(ceil(geometry.size.height / tileSize)))

            ZStack {
                Color(nsColor: .windowBackgroundColor)
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        if (row + col) % 2 == 0 {
                            Rectangle()
                                .fill(.secondary.opacity(0.08))
                                .frame(width: tileSize, height: tileSize)
                                .position(
                                    x: CGFloat(col) * tileSize + tileSize / 2,
                                    y: CGFloat(row) * tileSize + tileSize / 2
                                )
                        }
                    }
                }
            }
        }
    }

    private func loadImage() {
        image = nil
        loadError = nil
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            loadError = String(format: LumiPluginLocalization.string("File not found: %@", bundle: .module), fileURL.lastPathComponent)
            return
        }
        guard let loadedImage = NSImage(contentsOf: fileURL) else {
            loadError = String(format: LumiPluginLocalization.string("Failed to load image: %@", bundle: .module), fileURL.lastPathComponent)
            return
        }
        image = loadedImage
    }

    private var fileSizeString: String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? UInt64 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    private func fittedSize(original: CGSize, container: CGSize) -> CGSize {
        guard original.width > 0, original.height > 0,
              container.width > 0, container.height > 0 else {
            return .zero
        }
        let scale = min(container.width / original.width, container.height / original.height, 1)
        return CGSize(width: original.width * scale, height: original.height * scale)
    }
}
