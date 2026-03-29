import MagicKit
import SwiftUI
import CodeEditor

/// 文件预览视图
struct FilePreviewView: View {
    @EnvironmentObject var ProjectVM: ProjectVM

    /// 当前文件内容（本地加载）
    @State private var fileContent: String = ""
    @State private var persistedContent: String = ""
    @State private var isSaving: Bool = false
    @State private var saveErrorMessage: String?
    @State private var selectedTheme: CodeEditor.ThemeName = .default
    private static let themeStorageKey = "AgentFilePreview.SelectedCodeEditorTheme"

    /// 判断当前选择的文件是否为可预览的类型
    private var isPreviewableFile: Bool {
        guard let url = ProjectVM.selectedFileURL else { return false }
        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()

        // 首先检查是否是 Git 配置文件（通过完整文件名判断）
        if SupportedFileType.isPreviewable(fileName: fileName) {
            return true
        }

        // 然后通过扩展名判断
        return SupportedFileType.isPreviewable(fileExtension)
    }

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
                if isPreviewableFile {
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

            Text(String(localized: "File Preview", table: "AgentFilePreview"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer()

            if ProjectVM.isFileSelected && isPreviewableFile {
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
                .disabled(!hasUnsavedChanges || isSaving)
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

            Divider()
                .background(Color.white.opacity(0.1))

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
            // 文件名
            Text(ProjectVM.selectedFileURL?.lastPathComponent ?? "")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .lineLimit(2)

            // 文件路径
            Text(ProjectVM.selectedFileURL?.path ?? "")
                .font(.system(size: 9))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fileContentSection: some View {
        FileContentSectionView(
            content: $fileContent,
            fileExtension: fileExtension,
            fileName: fileName,
            theme: selectedTheme
        )
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
            return
        }

        // 检查是否是目录
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            fileContent = ""
            persistedContent = ""
            return
        }

        Task {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                await MainActor.run {
                    self.fileContent = content
                    self.persistedContent = content
                }
            } catch {
                await MainActor.run {
                    self.fileContent = "无法加载文件内容：\(error.localizedDescription)"
                    self.persistedContent = self.fileContent
                }
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        fileContent != persistedContent
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
}

// MARK: - Preview

#Preview {
    FilePreviewView()
        .inRootView()
}
