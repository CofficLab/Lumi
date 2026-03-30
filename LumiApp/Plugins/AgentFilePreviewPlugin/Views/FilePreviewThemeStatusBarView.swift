import CodeEditor
import MagicKit
import SwiftUI

/// 文件预览主题状态栏视图（Agent 模式底部状态栏）
struct FilePreviewThemeStatusBarView: View {
    @State private var selectedTheme: CodeEditor.ThemeName = .default

    private static let themeStorageKey = "AgentFilePreview.SelectedCodeEditorTheme"

    var body: some View {
        StatusBarHoverContainer(
            detailView: FilePreviewThemeDetailView(
                selectedTheme: $selectedTheme,
                onThemeSelected: { newTheme in
                    selectedTheme = newTheme
                    persistThemeSelection(newTheme)
                    NotificationCenter.postFilePreviewThemeDidChange(theme: newTheme)
                }
            ),
            id: "file-preview-theme-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 10))

                Text(formattedThemeName(selectedTheme))
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .onAppear {
            restoreThemeSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .filePreviewThemeDidChange)) { notification in
            guard let userInfo = notification.userInfo,
                  let themeRawValue = userInfo["theme"] as? String,
                  let newTheme = CodeEditor.availableThemes.first(where: { $0.rawValue == themeRawValue }) else {
                return
            }
            selectedTheme = newTheme
        }
    }

    // MARK: - Theme Persistence

    private func restoreThemeSelection() {
        guard let storedRawValue = FilePreviewThemeStateStore.loadString(forKey: Self.themeStorageKey) else { return }
        if let matchedTheme = CodeEditor.availableThemes.first(where: { $0.rawValue == storedRawValue }) {
            selectedTheme = matchedTheme
        }
    }

    private func persistThemeSelection(_ theme: CodeEditor.ThemeName) {
        FilePreviewThemeStateStore.saveString(theme.rawValue, forKey: Self.themeStorageKey)
    }

    private func formattedThemeName(_ theme: CodeEditor.ThemeName) -> String {
        theme.rawValue
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

// MARK: - File Preview Theme Detail View

/// 文件预览主题详情视图（在 popover 中显示）
struct FilePreviewThemeDetailView: View {
    @Binding var selectedTheme: CodeEditor.ThemeName
    let onThemeSelected: (CodeEditor.ThemeName) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerSection

            GlassDivider()

            // 主题列表
            themeListSection
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "paintpalette")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Color.semantic.primary)

            Text(String(localized: "File Preview Theme", table: "AgentFilePreview"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Theme List Section

    private var themeListSection: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !lightThemes.isEmpty {
                    themeSection(
                        title: String(localized: "Light Themes", table: "AgentFilePreview"),
                        themes: lightThemes
                    )

                    if !darkThemes.isEmpty || !otherThemes.isEmpty {
                        GlassDivider()
                            .padding(.horizontal, 12)
                    }
                }

                if !darkThemes.isEmpty {
                    themeSection(
                        title: String(localized: "Dark Themes", table: "AgentFilePreview"),
                        themes: darkThemes
                    )

                    if !otherThemes.isEmpty {
                        GlassDivider()
                            .padding(.horizontal, 12)
                    }
                }

                if !otherThemes.isEmpty {
                    themeSection(
                        title: String(localized: "Other Themes", table: "AgentFilePreview"),
                        themes: otherThemes
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Theme Section

    private func themeSection(title: String, themes: [CodeEditor.ThemeName]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 分组标题
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            // 主题选项
            VStack(spacing: 0) {
                ForEach(themes, id: \.rawValue) { theme in
                    ThemeMenuItem(
                        theme: theme,
                        isSelected: theme.rawValue == selectedTheme.rawValue,
                        action: {
                            onThemeSelected(theme)
                        }
                    )

                    if theme.rawValue != themes.last?.rawValue {
                        GlassDivider()
                            .padding(.leading, 36)
                    }
                }
            }
        }
    }

    // MARK: - Theme Collections

    private var lightThemes: [CodeEditor.ThemeName] {
        CodeEditor.availableThemes.filter { themeCategory(for: $0) == .light }
    }

    private var darkThemes: [CodeEditor.ThemeName] {
        CodeEditor.availableThemes.filter { themeCategory(for: $0) == .dark }
    }

    private var otherThemes: [CodeEditor.ThemeName] {
        CodeEditor.availableThemes.filter { themeCategory(for: $0) == .other }
    }

    // MARK: - Theme Categorization

    private enum ThemeCategory {
        case light
        case dark
        case other
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
}

// MARK: - Theme Menu Item

private struct ThemeMenuItem: View {
    let theme: CodeEditor.ThemeName
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // 主题预览色块
                themePreviewColor

                Text(formattedThemeName(theme))
                    .font(.system(size: 11))
                    .foregroundColor(isHovering ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isHovering ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(isHovering ? DesignTokens.Color.semantic.primary.opacity(0.15) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }

    /// 主题预览色块
    private var themePreviewColor: some View {
        Rectangle()
            .fill(previewColor)
            .frame(width: 16, height: 16)
            .cornerRadius(3)
    }

    /// 根据主题名称推测预览颜色
    private var previewColor: Color {
        let name = theme.rawValue.lowercased()

        if name.contains("light") || name.contains("day") {
            return Color.white
        }
        if name.contains("dark") || name.contains("night") || name.contains("black") {
            return Color.black
        }
        if name.contains("monokai") {
            return Color(red: 0.15, green: 0.15, blue: 0.15)
        }
        if name.contains("dracula") {
            return Color(red: 0.12, green: 0.12, blue: 0.18)
        }
        if name.contains("github") {
            return name.contains("dark") ? Color(red: 0.06, green: 0.06, blue: 0.06) : Color.white
        }
        if name.contains("solarized") {
            return name.contains("dark") ? Color(red: 0.0, green: 0.16, blue: 0.2) : Color(red: 0.99, green: 0.96, blue: 0.89)
        }
        if name.contains("nord") {
            return Color(red: 0.18, green: 0.2, blue: 0.25)
        }
        if name.contains("ocean") {
            return Color(red: 0.05, green: 0.09, blue: 0.16)
        }

        return Color.gray
    }

    private func formattedThemeName(_ theme: CodeEditor.ThemeName) -> String {
        theme.rawValue
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

// MARK: - Preview

#Preview("Status Bar View") {
    FilePreviewThemeStatusBarView()
        .frame(height: 30)
        .inRootView()
}

#Preview("Detail View") {
    FilePreviewThemeDetailView(
        selectedTheme: .constant(.default),
        onThemeSelected: { _ in }
    )
    .frame(width: 280, height: 400)
    .appSurface(style: .glass)
}
