import AppKit
import LumiPreviewKit
import MagicAlert
import MagicKit
import MarkdownKit
import os
import SwiftUI
import StringCatalogKit

/// 预览插件的底部面板内容视图。
///
/// 提供以下功能：
/// - 自动启动 `LumiPreviewHostApp` 子进程，订阅帧流，实时显示预览。
/// - 自动构建：打开 Swift 文件并保存时自动扫描 `#Preview`，编译并加载。
/// - 图片预览：图片文件直接在主进程显示，不启动预览子进程。
struct EditorPreviewDetailView: View, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.view"
    )
    nonisolated static let emoji = "👁"
    nonisolated static let verbose: Bool = true

    @EnvironmentObject private var editorVM: WindowEditorVM
    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var themeVM: AppThemeVM
    @StateObject private var viewModel = EditorPreviewViewModel()
    @StateObject private var automationState = InlinePreviewAutomationState.shared
    @State private var isCleaningCurrentStringCatalog = false
    @State private var isCleaningProjectStringCatalogs = false
    @State private var isConfirmingProjectStringCatalogClean = false

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
                alert_info(String(localized: "Automation: start preview stream", table: "EditorPreview"))
                viewModel.startSession()
            case "inline_preview.stop_stream", "inline_preview.stopStream":
                if Self.verbose {
                    Self.logger.info("\(self.t)🤖 自动化：收到 stop_stream 动作")
                }
                alert_info(String(localized: "Automation: stop preview stream", table: "EditorPreview"))
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
                alert_info(String(localized: "Automation: start preview stream", table: "EditorPreview"))
                viewModel.startSession()
            case .stop:
                if Self.verbose {
                    Self.logger.info("\(self.t)🤖 自动化状态：消费 sessionAction=.stop")
                }
                alert_info(String(localized: "Automation: stop preview stream", table: "EditorPreview"))
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
                markdownTODOBadge
                stringCatalogControls
            }

            Spacer()

            if viewModel.previewMode == .swift {
                entryStatusBadge

                buildInfoBadge

                cacheControls

                statusBadge

                entryDebugControls
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .confirmationDialog(
            String(localized: "Clean all stale String Catalog keys in this project?", table: "EditorPreview"),
            isPresented: $isConfirmingProjectStringCatalogClean,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Clean Project String Catalogs", table: "EditorPreview"), role: .destructive) {
                cleanProjectStringCatalogs()
            }
            Button(String(localized: "Cancel", table: "EditorPreview"), role: .cancel) {}
        } message: {
            Text(String(localized: "This rewrites every .xcstrings file under the current project and removes entries marked as stale.", table: "EditorPreview"))
        }
    }

    @ViewBuilder
    private var staticPreviewModeBadge: some View {
        switch viewModel.previewMode {
        case .image:
            Label(String(localized: "Image Preview", table: "EditorPreview"), systemImage: "photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .markdown:
            Label(String(localized: "Markdown Preview", table: "EditorPreview"), systemImage: "doc.richtext")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .stringCatalog:
            Label(String(localized: "String Catalog Preview", table: "EditorPreview"), systemImage: "character.book.closed")
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
            .help(String(localized: "Markdown TODO completion", table: "EditorPreview"))
        }
    }

    @ViewBuilder
    private var stringCatalogControls: some View {
        if case .stringCatalog = viewModel.previewMode {
            if let catalog = currentStringCatalog {
                if catalog.staleEntryCount > 0 {
                    Label("\(catalog.staleEntryCount)", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help(String(localized: "Stale String Catalog keys in the current file", table: "EditorPreview"))
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
                .help(String(localized: "Clean stale keys in the current String Catalog file", table: "EditorPreview"))
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
                projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .help(String(localized: "Clean stale keys in every String Catalog file in the current project", table: "EditorPreview"))
        }
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
                String(localized: "Preview", table: "EditorPreview"),
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
            .help(String(localized: "Choose which #Preview in the current Swift file to build and render.", table: "EditorPreview"))
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
            ? String(localized: "cache", table: "EditorPreview")
            : String(localized: "rebuilt", table: "EditorPreview")
        let time = Self.buildTimeFormatter.string(from: info.completedAt)
        return "\(mode) · \(time) · \(info.previewCount) preview(s)"
    }

    @ViewBuilder
    private var cacheControls: some View {
        let summary = viewModel.cacheSummary
        if !summary.isEmpty {
            HStack(spacing: 4) {
                Label(
                    "\(String(localized: "cache", table: "EditorPreview")) · \(summary.formattedByteCount)",
                    systemImage: "externaldrive"
                )
                .labelStyle(.titleAndIcon)

                Button {
                    viewModel.purgeBuildCaches()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Clear Inline Preview build cache", table: "EditorPreview"))
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
            .help(String(localized: "Refresh entry debug state", table: "EditorPreview"))
        }
    }

    private var canRequestEntryDebugState: Bool {
        guard viewModel.status == .running else { return false }
        if case .loaded = viewModel.entryStatus {
            return true
        }
        return false
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
            let removedCount = try viewModel.cleanCurrentStringCatalog(
                fileURL: currentFileURL,
                sourceText: sourceText,
                editorService: editorVM.service
            )
            if removedCount > 0 {
                alert_success(
                    String(
                        format: String(localized: "Removed %d stale String Catalog key(s).", table: "EditorPreview"),
                        removedCount
                    )
                )
            } else {
                alert_info(String(localized: "No stale String Catalog keys found.", table: "EditorPreview"))
            }
        } catch {
            alert_error(
                String(
                    format: String(localized: "Failed to clean String Catalog: %@", table: "EditorPreview"),
                    error.localizedDescription
                )
            )
        }
    }

    private func cleanProjectStringCatalogs() {
        guard !isCleaningProjectStringCatalogs else { return }
        let projectRootPath = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectRootPath.isEmpty else {
            alert_warning(String(localized: "Select a project before cleaning String Catalogs.", table: "EditorPreview"))
            return
        }

        isCleaningProjectStringCatalogs = true
        Task {
            do {
                let summary = try await viewModel.cleanProjectStringCatalogs(
                    projectRootPath: projectRootPath,
                    currentFileURL: currentFileURL,
                    currentSourceText: sourceText,
                    editorService: editorVM.service
                )
                isCleaningProjectStringCatalogs = false

                if summary.removedEntryCount > 0 {
                    alert_success(
                        String(
                            format: String(localized: "Removed %d stale key(s) from %d String Catalog file(s).", table: "EditorPreview"),
                            summary.removedEntryCount,
                            summary.changedFileCount
                        )
                    )
                } else {
                    alert_info(
                        String(
                            format: String(localized: "Scanned %d String Catalog file(s); no stale keys found.", table: "EditorPreview"),
                            summary.scannedFileCount
                        )
                    )
                }
            } catch {
                isCleaningProjectStringCatalogs = false
                alert_error(
                    String(
                        format: String(localized: "Failed to clean project String Catalogs: %@", table: "EditorPreview"),
                        error.localizedDescription
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var entryStatusBadge: some View {
        switch viewModel.entryStatus {
        case .noPreview:
            EmptyView()
        case let .building(file):
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text(String(localized: "building \(file)", table: "EditorPreview"))
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .lineLimit(1)
        case let .loading(path):
            Text(String(localized: "loading \((path as NSString).lastPathComponent)", table: "EditorPreview"))
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(1)
                .truncationMode(.middle)
        case let .loaded(_, title):
            Text(String(localized: "entry · \(title)", table: "EditorPreview"))
                .font(.caption)
                .foregroundStyle(.green)
                .lineLimit(1)
                .truncationMode(.middle)
        case let .failed(failure):
            Text(failure.title)
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
        case .warming:
            Text(String(localized: "warming", table: "EditorPreview")).font(.caption).foregroundStyle(.orange)
        case .ready:
            Text(String(localized: "ready", table: "EditorPreview")).font(.caption).foregroundStyle(.secondary)
        case .starting:
            Text(String(localized: "starting", table: "EditorPreview")).font(.caption).foregroundStyle(.orange)
        case .running:
            Text(String(localized: "running · \(viewModel.policy.rawValue)", table: "EditorPreview")).font(.caption).foregroundStyle(.green)
        case .stopping:
            Text(String(localized: "stopping", table: "EditorPreview")).font(.caption).foregroundStyle(.orange)
        case let .failed(message):
            Text(String(localized: "failed: \(message)", table: "EditorPreview"))
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
            EditorPreviewImageView(fileURL: url)
        case .markdown:
            EditorPreviewMarkdownView(markdown: sourceText ?? "")
                .environmentObject(themeVM)
        case .stringCatalog:
            EditorPreviewStringCatalogContainer(sourceText: sourceText ?? "")
                .environmentObject(themeVM)
        case let .unsupported(url):
            unsupportedPreview(url: url)
        }
    }

    @ViewBuilder
    private var swiftPreviewCanvas: some View {
        let hasFrame = viewModel.currentFrame != nil
        GeometryReader { proxy in
            ZStack {
                EditorPreviewBoardGrid()

                if !hasFrame {
                    VStack(spacing: 12) {
                        if viewModel.entryStatus == .noPreview, currentFileURL?.pathExtension == "swift" {
                            Image(systemName: "bolt.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text(String(localized: "No #Preview in the current Swift file.", table: "EditorPreview"))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        } else {
                            Image(systemName: "rectangle.dashed")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text(String(localized: "Open a Swift file with a `#Preview`; Inline Preview starts automatically and refreshes when you save.", table: "EditorPreview"))
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
                    VStack {
                        Spacer()
                        EditorPreviewFailureDetailsView(failure: failure)
                            .padding(16)
                    }
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
                    EditorPreviewBuildingOverlay(fileName: file)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entryFailure: EditorPreviewViewModel.EntryFailure? {
        if case let .failed(failure) = viewModel.entryStatus {
            return failure
        }
        return nil
    }

    private var buildingFileName: String? {
        if case let .building(file) = viewModel.entryStatus {
            return file
        }
        return nil
    }

    private func unsupportedPreview(url: URL?) -> some View {
        ZStack {
            EditorPreviewBoardGrid()
            VStack(spacing: 12) {
                Image(systemName: "doc")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(url == nil
                     ? String(localized: "Open a Swift file with a `#Preview`, an image, Markdown, or String Catalog file to preview it here.", table: "EditorPreview")
                     : String(localized: "This file type is not supported by Inline Preview yet.", table: "EditorPreview"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

private struct EditorPreviewDebugStateView: View {
    let state: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .foregroundStyle(.blue)
                Text(String(localized: "Entry debug state", table: "EditorPreview"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Show entry debug state", table: "EditorPreview"))
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

private struct EditorPreviewBuildingOverlay: View {
    let fileName: String

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.regular)
            Text(String(localized: "building \(fileName)", table: "EditorPreview"))
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(fileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minWidth: 220, maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .padding(24)
    }
}

private struct MarkdownTODOStats: Equatable {
    let total: Int
    let completed: Int

    var ratio: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var percent: Int {
        Int((ratio * 100).rounded())
    }
}

private enum MarkdownTODOScanner {
    static func scan(_ markdown: String) -> MarkdownTODOStats? {
        var total = 0
        var completed = 0

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            if trimmed.hasPrefix("- [ ]") {
                total += 1
            } else if trimmed.hasPrefix("- [x]") {
                total += 1
                completed += 1
            }
        }

        guard total > 0 else { return nil }
        return MarkdownTODOStats(total: total, completed: completed)
    }
}

private struct MarkdownTOCHeading: Identifiable, Hashable {
    let id: String
    let level: Int
    let title: String
    let lineNumber: Int
}

private struct MarkdownTOCSection: Identifiable {
    let id: String
    let markdown: String
}

private enum MarkdownTOCScanner {
    static func scan(_ markdown: String) -> (headings: [MarkdownTOCHeading], sections: [MarkdownTOCSection]) {
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

    let markdown: String
    @State private var scrollToID: String?

    private var toc: (headings: [MarkdownTOCHeading], sections: [MarkdownTOCSection]) {
        MarkdownTOCScanner.scan(markdown)
    }

    var body: some View {
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
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    private var emptyMarkdownView: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(String(localized: "No Markdown content to preview.", table: "EditorPreview"))
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
                    .environment(\.codeHighlightProvider, currentHighlightProvider)
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
                Text("TOC")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                ForEach(headings) { heading in
                    Button {
                        scrollToID = heading.id
                    } label: {
                        Text(heading.title)
                            .font(.system(size: 12, weight: heading.level <= 2 ? .semibold : .regular))
                            .foregroundStyle(themeVM.activeAppTheme.workspaceTextColor())
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
                }
            }
            .padding(.vertical, 14)
        }
        .frame(width: 220)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor().opacity(0.72))
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

private struct EditorPreviewFailureDetailsView: View {
    let failure: EditorPreviewViewModel.EntryFailure

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: failure.systemImage)
                    .foregroundStyle(.orange)
                Text(failure.title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Show error details", table: "EditorPreview"))
            }

            if isExpanded {
                ScrollView {
                    Text(failure.message)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 180)
                .background(Color.black.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(failure.message)
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

private struct EditorPreviewStringCatalogContainer: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    let sourceText: String

    var body: some View {
        Group {
            if sourceText.isEmpty {
                messageView(
                    systemImage: "character.book.closed",
                    text: String(localized: "No String Catalog content to preview.", table: "EditorPreview")
                )
            } else {
                switch parseResult {
                case let .success(catalog):
                    EditorPreviewStringCatalogView(catalog: catalog)
                        .environmentObject(themeVM)
                case let .failure(error):
                    messageView(
                        systemImage: "exclamationmark.triangle",
                        text: String(
                            format: String(localized: "Failed to load string catalog: %@", table: "EditorPreview"),
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
            EditorPreviewBoardGrid()
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
                    Text(String(localized: "Default Localization", table: "EditorPreview"))
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

                Spacer()
            }
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            headerCell(String(localized: "Key", table: "EditorPreview"), width: 340)
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
            format: String(localized: "Default Localization (%@)", table: "EditorPreview"),
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

private struct EditorPreviewImageView: View {
    let fileURL: URL

    @State private var image: NSImage?
    @State private var loadError: String?

    var body: some View {
        ZStack {
            EditorPreviewBoardGrid()

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
            loadError = String(format: String(localized: "File not found: %@", table: "EditorPreview"), fileURL.lastPathComponent)
            return
        }
        guard let loadedImage = NSImage(contentsOf: fileURL) else {
            loadError = String(format: String(localized: "Failed to load image: %@", table: "EditorPreview"), fileURL.lastPathComponent)
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
