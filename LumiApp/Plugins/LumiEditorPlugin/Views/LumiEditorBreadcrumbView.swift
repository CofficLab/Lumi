import SwiftUI
import MagicKit
import CodeEditLanguages

/// 面包屑导航视图
struct LumiEditorBreadcrumbView: View {
    
    @EnvironmentObject private var projectVM: ProjectVM
    @ObservedObject var state: LumiEditorState
    
    /// 面包屑项
    private struct BreadcrumbItem: Identifiable {
        let index: Int
        let name: String
        let url: URL
        let isDirectory: Bool
        var id: Int { index }
    }
    
    /// 面包屑路径段列表
    private var breadcrumbItems: [BreadcrumbItem] {
        guard let fileURL = projectVM.selectedFileURL else { return [] }
        
        let fullPath = fileURL.standardizedFileURL.path
        if let projectPath = projectVM.currentProject?.path,
           fullPath.hasPrefix(projectPath + "/") {
            let relative = String(fullPath.dropFirst(projectPath.count + 1))
            let segments = relative.split(separator: "/").map(String.init)
            var runningPath = projectPath
            
            return segments.enumerated().map { index, segment in
                runningPath += "/" + segment
                let segmentURL = URL(fileURLWithPath: runningPath)
                let isDirectory = (try? segmentURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return BreadcrumbItem(index: index, name: segment, url: segmentURL, isDirectory: isDirectory)
            }
        }
        
        let segments = fullPath.split(separator: "/").map(String.init)
        var runningPath = ""
        
        return segments.enumerated().map { index, segment in
            runningPath += "/" + segment
            let segmentURL = URL(fileURLWithPath: runningPath)
            let isDirectory = (try? segmentURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return BreadcrumbItem(index: index, name: segment, url: segmentURL, isDirectory: isDirectory)
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 面包屑路径
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(breadcrumbItems) { item in
                        let isLast = item.index == breadcrumbItems.count - 1
                        
                        if item.index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppUI.Color.semantic.textTertiary)
                                .padding(.horizontal, 1)
                        }
                        
                        Text(item.name)
                            .font(.system(size: 11, weight: isLast ? .semibold : .regular))
                            .foregroundColor(
                                isLast
                                    ? AppUI.Color.semantic.textPrimary
                                    : AppUI.Color.semantic.textSecondary
                            )
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            
            // 右侧：保存状态 + 语言标签（固定宽度，不被路径挤压）
            HStack(spacing: 6) {
                saveStateIndicator
                
                if let lang = state.detectedLanguage {
                    Text(languageDisplayName(lang))
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .frame(height: AppConfig.headerHeight)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: AppConfig.headerHeight)
    }
    
    // MARK: - Save State Indicator
    
    @ViewBuilder
    private var saveStateIndicator: some View {
        switch state.saveState {
        case .idle:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        case .editing:
            Image(systemName: "pencil.circle")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        case .saving:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 14, height: 14)
        case .saved:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.success)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.error)
        }
    }
    
    // MARK: - Helpers
    
    private func languageDisplayName(_ language: CodeLanguage) -> String {
        let tsName = language.tsName
        let nameMap: [String: String] = [
            "swift": "Swift",
            "c": "C",
            "cpp": "C++",
            "objective-c": "Objective-C",
            "java": "Java",
            "kotlin": "Kotlin",
            "python": "Python",
            "javascript": "JavaScript",
            "typescript": "TypeScript",
            "tsx": "TSX",
            "jsx": "JSX",
            "rust": "Rust",
            "go": "Go",
            "ruby": "Ruby",
            "php": "PHP",
            "html": "HTML",
            "css": "CSS",
            "json": "JSON",
            "yaml": "YAML",
            "toml": "TOML",
            "markdown": "Markdown",
            "sql": "SQL",
            "bash": "Shell",
            "lua": "Lua",
            "elixir": "Elixir",
            "erlang": "Erlang",
            "scala": "Scala",
            "haskell": "Haskell",
            "c-sharp": "C#",
            "dart": "Dart",
            "zig": "Zig",
            "perl": "Perl",
            "r": "R",
        ]
        return nameMap[tsName] ?? tsName.capitalized
    }
}
