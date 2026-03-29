import CodeEditor
import MagicKit
import SwiftUI

/// 文件预览视图
struct FilePreviewView: View {
    @EnvironmentObject var ProjectVM: ProjectVM

    /// 当前文件内容（本地加载）
    @State private var fileContent: String = ""
    @State private var persistedContent: String = ""
    @State private var isSaving: Bool = false
    @State private var saveErrorMessage: String?
    @State private var selectedTheme: CodeEditor.ThemeName = .default
    @State private var canPreviewCurrentFile: Bool = false
    @State private var isReadOnlyPreview: Bool = false
    @State private var isTruncatedPreview: Bool = false
    private static let themeStorageKey = "AgentFilePreview.SelectedCodeEditorTheme"
    private static let textProbeBytes = 8192
    private static let readOnlyThresholdBytes: Int64 = 512 * 1024
    private static let truncationThresholdBytes: Int64 = 2 * 1024 * 1024
    private static let truncationReadBytes = 256 * 1024

    /// 获取当前文件扩展名
    private var fileExtension: String {
        guard let url = ProjectVM.selectedFileURL else { return "" }
        return url.pathExtension.lowercased()
    }

    /// 获取当前文件完整名称
    private var fileName: String {
        guard let url = ProjectVM.selectedFileURL else { return "" }
        return url.lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerSection

            Divider()
                .background(Color.white.opacity(0.1))

            // 文件预览内容
            if ProjectVM.isFileSelected {
                if canPreviewCurrentFile {
                    filePreviewContent
                } else {
                    FilePreviewUnsupportedView(fileName: "\(ProjectVM.selectedFileURL?.lastPathComponent ?? "")")
                }
            } else {
                FilePreviewEmptyStateView()
            }
        }
        .background(AppUI.Material.glassThick)
        .onChange(of: ProjectVM.selectedFileURL) { _, newURL in
            loadFileContent(from: newURL)
        }
        .onAppear {
            restoreThemeSelection()
            loadFileContent(from: ProjectVM.selectedFileURL)
        }
        .onChange(of: selectedTheme) { _, newTheme in
            persistThemeSelection(newTheme)
        }
        .alert(String(localized: "Save Failed", table: "AgentFilePreview"), isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "doc.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            Text(headerTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer()

            if ProjectVM.isFileSelected && canPreviewCurrentFile {
                themeMenu

                if hasUnsavedChanges {
                    Circle()
                        .fill(AppUI.Color.semantic.warning)
                        .frame(width: 6, height: 6)
                }

                Button(action: saveFileContent) {
                    HStack(spacing: 4) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10))
                        }

                        Text(String(localized: "Save", table: "AgentFilePreview"))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(hasUnsavedChanges ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(!hasUnsavedChanges || isSaving || isReadOnlyPreview)
            }

            // 清除选择按钮
            Button(action: clearSelection) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: AppConfig.headerHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
    }

    // MARK: - File Preview Content

    private var filePreviewContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 文件信息
            fileInfoSection

            // 文件内容
            fileContentSection
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isTruncatedPreview {
                Text(String(localized: "Preview Truncated for Large File", table: "AgentFilePreview"))
                    .font(.system(size: 9))
                    .foregroundColor(AppUI.Color.semantic.warning)
                    .lineLimit(2)
            } else if isReadOnlyPreview {
                Text(String(localized: "Large File Read-Only Preview", table: "AgentFilePreview"))
                    .font(.system(size: 9))
                    .foregroundColor(AppUI.Color.semantic.warning)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fileContentSection: some View {
        FileContentSectionView(
            content: $fileContent,
            fileExtension: fileExtension,
            fileName: fileName,
            theme: selectedTheme,
            isEditable: !isReadOnlyPreview && canPreviewCurrentFile,
            forcePlainText: isReadOnlyPreview
        )
    }

    private var headerTitle: String {
        if ProjectVM.isFileSelected, let fileName = ProjectVM.selectedFileURL?.lastPathComponent, !fileName.isEmpty {
            return fileName
        }
        return String(localized: "File Preview", table: "AgentFilePreview")
    }

    private var themeMenu: some View {
        Menu {
            if !lightThemes.isEmpty {
                Section(String(localized: "Light Themes", table: "AgentFilePreview")) {
                    ForEach(lightThemes, id: \.rawValue) { theme in
                        themeSelectionButton(theme)
                    }
                }
            }

            if !darkThemes.isEmpty {
                Section(String(localized: "Dark Themes", table: "AgentFilePreview")) {
                    ForEach(darkThemes, id: \.rawValue) { theme in
                        themeSelectionButton(theme)
                    }
                }
            }

            if !otherThemes.isEmpty {
                Section(String(localized: "Other Themes", table: "AgentFilePreview")) {
                    ForEach(otherThemes, id: \.rawValue) { theme in
                        themeSelectionButton(theme)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 10))
                Text(formattedThemeName(selectedTheme))
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .menuStyle(.borderlessButton)
    }

    private var lightThemes: [CodeEditor.ThemeName] {
        CodeEditor.availableThemes.filter { themeCategory(for: $0) == .light }
    }

    private var darkThemes: [CodeEditor.ThemeName] {
        CodeEditor.availableThemes.filter { themeCategory(for: $0) == .dark }
    }

    private var otherThemes: [CodeEditor.ThemeName] {
        CodeEditor.availableThemes.filter { themeCategory(for: $0) == .other }
    }

    private enum ThemeCategory {
        case light
        case dark
        case other
    }

    private func themeSelectionButton(_ theme: CodeEditor.ThemeName) -> some View {
        Button(action: { selectedTheme = theme }) {
            HStack {
                Text(formattedThemeName(theme))
                if theme.rawValue == selectedTheme.rawValue {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    // MARK: - Actions

    private func loadFileContent(from url: URL?) {
        guard let url = url else {
            fileContent = ""
            persistedContent = ""
            canPreviewCurrentFile = false
            isReadOnlyPreview = false
            isTruncatedPreview = false
            return
        }

        // 检查是否是目录
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            fileContent = ""
            persistedContent = ""
            canPreviewCurrentFile = false
            isReadOnlyPreview = false
            isTruncatedPreview = false
            return
        }

        let selectedURL = url
        Task {
            do {
                let fileSize = Int64((try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                guard try isLikelyTextFile(url: url) else {
                    await MainActor.run {
                        guard ProjectVM.selectedFileURL == selectedURL else { return }
                        self.fileContent = ""
                        self.persistedContent = ""
                        self.canPreviewCurrentFile = false
                        self.isReadOnlyPreview = false
                        self.isTruncatedPreview = false
                    }
                    return
                }

                let shouldTruncate = fileSize > Self.truncationThresholdBytes
                let shouldReadOnly = fileSize > Self.readOnlyThresholdBytes
                let content: String
                if shouldTruncate {
                    content = try readTruncatedContent(from: url, maxBytes: Self.truncationReadBytes)
                } else {
                    var detectedEncoding = String.Encoding.utf8
                    content = try String(contentsOf: url, usedEncoding: &detectedEncoding)
                }

                await MainActor.run {
                    guard ProjectVM.selectedFileURL == selectedURL else { return }
                    self.fileContent = content
                    self.persistedContent = content
                    self.canPreviewCurrentFile = true
                    self.isReadOnlyPreview = shouldReadOnly
                    self.isTruncatedPreview = shouldTruncate
                }
            } catch {
                await MainActor.run {
                    guard ProjectVM.selectedFileURL == selectedURL else { return }
                    self.fileContent = "无法加载文件内容：\(error.localizedDescription)"
                    self.persistedContent = ""
                    self.canPreviewCurrentFile = false
                    self.isReadOnlyPreview = false
                    self.isTruncatedPreview = false
                }
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        !isReadOnlyPreview && fileContent != persistedContent
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    saveErrorMessage = nil
                }
            }
        )
    }

    private func saveFileContent() {
        guard let url = ProjectVM.selectedFileURL, hasUnsavedChanges else { return }
        let contentToSave = fileContent
        isSaving = true

        Task {
            do {
                try contentToSave.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run {
                    persistedContent = contentToSave
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    saveErrorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    private func clearSelection() {
        self.ProjectVM.clearFileSelection()
    }

    private func formattedThemeName(_ theme: CodeEditor.ThemeName) -> String {
        theme.rawValue
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func themeCategory(for theme: CodeEditor.ThemeName) -> ThemeCategory {
        let name = theme.rawValue.lowercased()

        if name.contains("light") || name.contains("day") || name.contains("github") || name.contains("xcode") || name.contains("solarized-light") || name.contains("tomorrow") || name.contains("googlecode") {
            return .light
        }

        if name.contains("dark") || name.contains("night") || name.contains("black") || name.contains("monokai") || name.contains("dracula") || name.contains("ocean") || name.contains("obsidian") || name.contains("nord") || name.contains("atom-one-dark") || name.contains("github-dark") || name.contains("solarized-dark") || name.contains("tomorrow-night") {
            return .dark
        }

        return .other
    }

    private func restoreThemeSelection() {
        guard let storedRawValue = FilePreviewThemeStateStore.loadString(forKey: Self.themeStorageKey) else { return }
        if let matchedTheme = CodeEditor.availableThemes.first(where: { $0.rawValue == storedRawValue }) {
            selectedTheme = matchedTheme
        }
    }

    private func persistThemeSelection(_ theme: CodeEditor.ThemeName) {
        FilePreviewThemeStateStore.saveString(theme.rawValue, forKey: Self.themeStorageKey)
    }

    private func readTruncatedContent(from url: URL, maxBytes: Int) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let data = try handle.read(upToCount: maxBytes) ?? Data()
        let preview = String(decoding: data, as: UTF8.self)
        let suffix = "\n\n… " + String(localized: "File too large. Preview is truncated.", table: "AgentFilePreview")
        return preview + suffix
    }

    private func isLikelyTextFile(url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let sample = try handle.read(upToCount: Self.textProbeBytes) ?? Data()
        if sample.isEmpty { return true }

        if sample.contains(0) {
            return false
        }

        var controlByteCount = 0
        for byte in sample {
            if byte == 0x09 || byte == 0x0A || byte == 0x0D {
                continue
            }
            if byte < 0x20 {
                controlByteCount += 1
            }
        }

        let ratio = Double(controlByteCount) / Double(sample.count)
        return ratio < 0.05
    }
}

// MARK: - Preview

#Preview {
    FilePreviewView()
        .inRootView()
}
