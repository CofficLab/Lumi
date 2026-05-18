import AppKit
import LumiInlinePreviewKit
import MagicAlert
import MagicKit
import MarkdownKit
import os
import SwiftUI
import StringCatalogKit

/// 内嵌预览插件的底部面板内容视图。
///
/// 提供以下功能：
/// - 自动启动 `LumiInlinePreviewHostApp` 子进程，订阅帧流，实时显示预览。
/// - 自动构建：打开 Swift 文件并保存时自动扫描 `#Preview`，编译并加载。
/// - 图片预览：图片文件直接在主进程显示，不启动预览子进程。
struct EditorInlinePreviewDetailView: View, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.view"
    )
    nonisolated static let emoji = "👁"
    nonisolated static let verbose: Bool = true

    @EnvironmentObject private var editorVM: EditorVM
    @EnvironmentObject private var themeVM: ThemeVM
    @StateObject private var viewModel = EditorInlinePreviewViewModel()
    @StateObject private var automationState = InlinePreviewAutomationState.shared

    private var sourceText: String? {
        editorVM.service.content?.string
    }

    private var currentFileURL: URL? {
        editorVM.service.currentFileURL
    }

    var body: some View {
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
            viewModel.wireEditorService(editorVM.service)
            viewModel.viewDidAppear(fileURL: currentFileURL, sourceText: sourceText)

            // 消费 AutomationController 可能在 View 出现之前就写入的 pending sessionAction。
            if let pendingAction = automationState.sessionAction {
                automationState.sessionAction = nil
                switch pendingAction {
                case .start:
                    if Self.verbose {
                        Self.logger.info("\(self.t)🤖 onAppear 消费 pending sessionAction=.start")
                    }
                    viewModel.startSession()
                case .stop:
                    if Self.verbose {
                        Self.logger.info("\(self.t)🤖 onAppear 消费 pending sessionAction=.stop")
                    }
                    viewModel.stopSession()
                }
            }
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
        .onChange(of: editorVM.service.saveRevision) { _, _ in
            if Self.verbose {
                Self.logger.info("\(self.t)💾 saveRevision 变更")
            }
            viewModel.applySaveRevision(sourceText: sourceText)
        }
        .onChange(of: editorVM.service.contentRevision) { _, _ in
            viewModel.updateBufferText(sourceText)
        }
        // 监听自动化测试动作
        .onAutomationAction { action, payload in
            switch action {
            case "inline_preview.start_stream", "inline_preview.startStream":
                if Self.verbose {
                    Self.logger.info("\(self.t)🤖 自动化：收到 start_stream 动作")
                }
                alert_info("自动化测试：启动预览流")
                viewModel.startSession()
            case "inline_preview.stop_stream", "inline_preview.stopStream":
                if Self.verbose {
                    Self.logger.info("\(self.t)🤖 自动化：收到 stop_stream 动作")
                }
                alert_info("自动化测试：停止预览流")
                viewModel.stopSession()
            default:
                break
            }
        }
        // 监听自动化共享状态
        .onChange(of: automationState.sessionAction) { oldAction, newAction in
            guard let newAction else { return }
            automationState.sessionAction = nil
            switch newAction {
            case .start:
                if Self.verbose {
                    Self.logger.info("\(self.t)🤖 自动化状态：消费 sessionAction=.start")
                }
                alert_info("自动化测试：启动预览流")
                viewModel.startSession()
            case .stop:
                if Self.verbose {
                    Self.logger.info("\(self.t)🤖 自动化状态：消费 sessionAction=.stop")
                }
                alert_info("自动化测试：停止预览流")
                viewModel.stopSession()
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            if viewModel.previewMode == .swift {
                entryControls
            } else {
                staticPreviewModeBadge
            }

            Spacer()

            if viewModel.previewMode == .swift {
                entryStatusBadge

                buildInfoBadge

                statusBadge

                if let frame = viewModel.currentFrame {
                    Text("seq \(frame.seq) · \(frame.width)×\(frame.height) @\(String(format: "%.0fx", frame.scale))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var staticPreviewModeBadge: some View {
        switch viewModel.previewMode {
        case .image:
            Label(String(localized: "Image Preview", table: "EditorInlinePreview"), systemImage: "photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .markdown:
            Label(String(localized: "Markdown Preview", table: "EditorInlinePreview"), systemImage: "doc.richtext")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .stringCatalog:
            Label(String(localized: "String Catalog Preview", table: "EditorInlinePreview"), systemImage: "character.book.closed")
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
    private var entryControls: some View {
        if viewModel.availablePreviews.count > 1 {
            Picker(
                String(localized: "Preview", table: "EditorInlinePreview"),
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
            .help(String(localized: "Choose which #Preview in the current Swift file to build and render.", table: "EditorInlinePreview"))
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

    private func buildInfoText(_ info: EditorInlinePreviewViewModel.BuildInfo) -> String {
        let mode = info.usedCache
            ? String(localized: "cache", table: "EditorInlinePreview")
            : String(localized: "rebuilt", table: "EditorInlinePreview")
        let time = Self.buildTimeFormatter.string(from: info.completedAt)
        return "\(mode) · \(time) · \(info.previewCount) preview(s)"
    }

    private static let buildTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    @ViewBuilder
    private var entryStatusBadge: some View {
        switch viewModel.entryStatus {
        case .noPreview:
            EmptyView()
        case let .building(file):
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text(String(localized: "building \(file)", table: "EditorInlinePreview"))
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .lineLimit(1)
        case let .loading(path):
            Text(String(localized: "loading \((path as NSString).lastPathComponent)", table: "EditorInlinePreview"))
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(1)
                .truncationMode(.middle)
        case let .loaded(_, title):
            Text(String(localized: "entry · \(title)", table: "EditorInlinePreview"))
                .font(.caption)
                .foregroundStyle(.green)
                .lineLimit(1)
                .truncationMode(.middle)
        case let .failed(message):
            Text(String(localized: "entry failed: \(message)", table: "EditorInlinePreview"))
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch viewModel.status {
        case .idle:
            EmptyView()
        case .starting:
            Text(String(localized: "starting", table: "EditorInlinePreview")).font(.caption).foregroundStyle(.orange)
        case .running:
            Text(String(localized: "running · \(viewModel.policy.rawValue)", table: "EditorInlinePreview")).font(.caption).foregroundStyle(.green)
        case .stopping:
            Text(String(localized: "stopping", table: "EditorInlinePreview")).font(.caption).foregroundStyle(.orange)
        case let .failed(message):
            Text(String(localized: "failed: \(message)", table: "EditorInlinePreview"))
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Canvas

    @ViewBuilder
    private var canvasArea: some View {
        switch viewModel.previewMode {
        case .swift:
            swiftPreviewCanvas
        case let .image(url):
            EditorInlinePreviewImageView(fileURL: url)
        case .markdown:
            EditorInlinePreviewMarkdownView(markdown: sourceText ?? "")
                .environmentObject(themeVM)
        case .stringCatalog:
            EditorInlinePreviewStringCatalogContainer(sourceText: sourceText ?? "")
                .environmentObject(themeVM)
        case let .unsupported(url):
            unsupportedPreview(url: url)
        }
    }

    @ViewBuilder
    private var swiftPreviewCanvas: some View {
        let hasFrame = viewModel.currentFrame != nil
        ZStack {
            EditorInlinePreviewBoardGrid()

            if !hasFrame {
                VStack(spacing: 12) {
                    if viewModel.entryStatus == .noPreview, currentFileURL?.pathExtension == "swift" {
                        Image(systemName: "bolt.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text(String(localized: "No #Preview in the current Swift file.", table: "EditorInlinePreview"))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        Image(systemName: "rectangle.dashed")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Open a Swift file with a `#Preview`; Inline Preview starts automatically and refreshes when you save.", table: "EditorInlinePreview"))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }

            LumiInlinePreviewFacade.PreviewSurfaceCanvas(
                surfaceID: viewModel.currentFrame?.surfaceID,
                isInteractive: viewModel.isInteractive,
                onSizeChange: { size, scale in
                    viewModel.canvasDidResize(size, scale: scale)
                },
                onInputEvent: { event in
                    viewModel.forwardInputEvent(event)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(hasFrame ? Color.clear : Color.black.opacity(0.01))

            if let message = entryFailureMessage {
                VStack {
                    Spacer()
                    EditorInlinePreviewFailureDetailsView(message: message)
                        .padding(16)
                }
            }
        }
    }

    private var entryFailureMessage: String? {
        if case let .failed(message) = viewModel.entryStatus {
            return message
        }
        return nil
    }

    private func unsupportedPreview(url: URL?) -> some View {
        ZStack {
            EditorInlinePreviewBoardGrid()
            VStack(spacing: 12) {
                Image(systemName: "doc")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(url == nil
                     ? String(localized: "Open a Swift file with a `#Preview`, an image, Markdown, or String Catalog file to preview it here.", table: "EditorInlinePreview")
                     : String(localized: "This file type is not supported by Inline Preview yet.", table: "EditorInlinePreview"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

private struct EditorInlinePreviewMarkdownView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    let markdown: String

    var body: some View {
        ScrollView {
            if markdown.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "No Markdown content to preview.", table: "EditorInlinePreview"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
                .padding(24)
            } else {
                MarkdownBlockRenderer(
                    markdown: markdown,
                    theme: previewTheme
                )
                .environment(\.codeHighlightProvider, currentHighlightProvider)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    private var previewTheme: MarkdownTheme {
        let theme = themeVM.activeAppTheme
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

    private var currentHighlightProvider: TreeSitterCodeHighlightProvider? {
        guard let contributor = themeVM.currentTheme?.editorThemeContributor
                as? any SuperEditorThemeContributor else {
            return nil
        }
        return TreeSitterCodeHighlightProvider(editorTheme: contributor.createTheme())
    }
}

private struct EditorInlinePreviewFailureDetailsView: View {
    let message: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(String(localized: "Preview failed", table: "EditorInlinePreview"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Show error details", table: "EditorInlinePreview"))
            }

            if isExpanded {
                ScrollView {
                    Text(message)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 180)
                .background(Color.black.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(message)
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
        .frame(maxWidth: 620)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

private struct EditorInlinePreviewStringCatalogContainer: View {
    @EnvironmentObject private var themeVM: ThemeVM

    let sourceText: String

    var body: some View {
        Group {
            if sourceText.isEmpty {
                messageView(
                    systemImage: "character.book.closed",
                    text: String(localized: "No String Catalog content to preview.", table: "EditorInlinePreview")
                )
            } else {
                switch parseResult {
                case let .success(catalog):
                    EditorInlinePreviewStringCatalogView(catalog: catalog)
                        .environmentObject(themeVM)
                case let .failure(error):
                    messageView(
                        systemImage: "exclamationmark.triangle",
                        text: String(
                            format: String(localized: "Failed to load string catalog: %@", table: "EditorInlinePreview"),
                            error.localizedDescription
                        )
                    )
                }
            }
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    private var parseResult: Result<StringCatalog, Error> {
        Result {
            try StringCatalogParser.parse(sourceText)
        }
    }

    private func messageView(systemImage: String, text: String) -> some View {
        ZStack {
            EditorInlinePreviewBoardGrid()
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

private struct EditorInlinePreviewStringCatalogView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    let catalog: StringCatalog
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

    var body: some View {
        HStack(spacing: 0) {
            languageSidebar
                .frame(width: 240)
            Divider()
            catalogTable
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
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
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    private func languageRow(_ language: StringCatalog.Language) -> some View {
        let isSelected = selectedLanguage.id == language.id
        let textColor = isSelected ? Color.white : themeVM.activeAppTheme.workspaceTextColor()
        let secondaryColor = isSelected ? Color.white.opacity(0.86) : themeVM.activeAppTheme.workspaceSecondaryTextColor()

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
                    Text(String(localized: "Default Localization", table: "EditorInlinePreview"))
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
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            headerCell(String(localized: "Key", table: "EditorInlinePreview"), width: 340)
            headerCell(sourceColumnTitle, width: 360)
            if selectedLanguage.id != sourceLanguage.id {
                headerCell(selectedLanguageColumnTitle, width: 360)
            }
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
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
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
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
            .foregroundColor(isMissing ? themeVM.activeAppTheme.workspaceSecondaryTextColor().opacity(0.58) : themeVM.activeAppTheme.workspaceTextColor())
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
            format: String(localized: "Default Localization (%@)", table: "EditorInlinePreview"),
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
    let text: String
    let isMissing: Bool

    var body: some View {
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

private struct EditorInlinePreviewImageView: View {
    let fileURL: URL

    @State private var image: NSImage?
    @State private var loadError: String?

    var body: some View {
        ZStack {
            EditorInlinePreviewBoardGrid()

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
            loadError = "File not found: \(fileURL.lastPathComponent)"
            return
        }
        guard let loadedImage = NSImage(contentsOf: fileURL) else {
            loadError = "Failed to load image: \(fileURL.lastPathComponent)"
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
