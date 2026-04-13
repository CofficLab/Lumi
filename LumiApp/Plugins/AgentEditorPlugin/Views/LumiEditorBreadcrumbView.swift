import SwiftUI
import MagicKit
import CodeEditLanguages

// MARK: - Breadcrumb Item Model

/// 面包屑路径段数据模型
struct BreadcrumbItem: Identifiable, Equatable {
    let index: Int
    let name: String
    let url: URL
    let isDirectory: Bool
    var id: Int { index }

    /// 获取同级的兄弟文件/文件夹列表
    var siblings: [BreadcrumbSibling] {
        let parentURL = url.deletingLastPathComponent()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .filter { $0.lastPathComponent != ".DS_Store" && $0.lastPathComponent != ".git" }
            .sorted { a, b in
                let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if aIsDir != bIsDir { return aIsDir }
                return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
            }
            .map { url in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return BreadcrumbSibling(name: url.lastPathComponent, url: url, isDirectory: isDir)
            }
    }
}

/// 面包屑兄弟节点（用于下拉菜单列表）
struct BreadcrumbSibling: Identifiable, Equatable {
    let name: String
    let url: URL
    let isDirectory: Bool
    var id: String { url.path }
}

// MARK: - Breadcrumb View

/// 面包屑导航视图
/// 参考 CodeEdit JumpBar 设计：每个路径段可点击弹出菜单，显示同级文件列表
struct LumiEditorBreadcrumbView: View {

    @EnvironmentObject private var projectVM: ProjectVM
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var state: LumiEditorState

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

    /// 容器宽度
    @State private var containerWidth: CGFloat = 0
    /// 面包屑文本总宽度
    @State private var textWidth: CGFloat = 0
    /// 非首段截断宽度
    @State private var crumbWidth: CGFloat?
    /// 首段截断宽度
    @State private var firstCrumbWidth: CGFloat?

    var body: some View {
        HStack(spacing: 0) {
            // 面包屑路径
            GeometryReader { containerProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        if !breadcrumbItems.isEmpty {
                            ForEach(breadcrumbItems) { item in
                                let isLast = item.index == breadcrumbItems.count - 1

                                BreadcrumbComponent(
                                    item: item,
                                    isLastItem: isLast,
                                    truncatedCrumbWidth: item.index == 0 ? $firstCrumbWidth : $crumbWidth,
                                    onSelectFile: { url in
                                        projectVM.selectFile(at: url)
                                    }
                                )
                            }
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear {
                                    if crumbWidth == nil {
                                        textWidth = proxy.size.width
                                    }
                                }
                                .onChange(of: proxy.size.width) { _, newValue in
                                    if crumbWidth == nil {
                                        textWidth = newValue
                                    }
                                }
                        }
                    )
                }
                .onAppear {
                    containerWidth = containerProxy.size.width
                }
                .onChange(of: containerProxy.size.width) { _, newValue in
                    containerWidth = newValue
                }
                .onChange(of: textWidth) { _, _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        recalculateTruncation()
                    }
                }
                .onChange(of: containerWidth) { _, _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        recalculateTruncation()
                    }
                }
            }
            .frame(height: Self.crumbHeight)
            .padding(.leading, 8)

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

    // MARK: - Truncation Logic

    /// 参考 CodeEdit JumpBar 的智能截断策略
    private func recalculateTruncation() {
        let itemCount = breadcrumbItems.count
        guard itemCount > 0 else {
            crumbWidth = nil
            firstCrumbWidth = nil
            return
        }

        let minWidth: CGFloat = 20
        let snapThreshold: CGFloat = 30
        let maxWidth: CGFloat = textWidth / CGFloat(itemCount)
        let exponent: CGFloat = 5.0
        var betweenWidth: CGFloat = 0.0

        if textWidth >= containerWidth {
            let scale = max(0, min(1, containerWidth / textWidth))
            betweenWidth = floor((minWidth + (maxWidth - minWidth) * pow(scale, exponent)))
            if betweenWidth < snapThreshold {
                betweenWidth = minWidth
            }
            crumbWidth = betweenWidth
        } else {
            crumbWidth = nil
        }

        if betweenWidth > snapThreshold || crumbWidth == nil {
            firstCrumbWidth = nil
        } else {
            let otherCrumbs = CGFloat(max(itemCount - 1, 1))
            let usedWidth = otherCrumbs * snapThreshold

            // Multiplier to reserve extra space for other crumbs.
            let crumbSpacingMultiplier: CGFloat = 1.5
            let availableForFirst = containerWidth - usedWidth * crumbSpacingMultiplier
            if availableForFirst < snapThreshold {
                firstCrumbWidth = minWidth
            } else {
                firstCrumbWidth = availableForFirst
            }
        }
    }

    // MARK: - Constants

    /// 面包屑行高
    static let crumbHeight: CGFloat = 28.0

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

// MARK: - Breadcrumb Component (单个路径段)

/// 单个面包屑路径段组件
/// 参考 CodeEdit 的 EditorJumpBarComponent，支持点击弹出菜单显示同级文件
struct BreadcrumbComponent: View {
    let item: BreadcrumbItem
    let isLastItem: Bool
    @Binding var truncatedCrumbWidth: CGFloat?
    let onSelectFile: (URL) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var isMenuVisible = false

    var body: some View {
        HStack(spacing: 0) {
            // 文件名按钮（带弹出菜单）
            Menu {
                BreadcrumbMenuContent(
                    siblings: item.siblings,
                    currentURL: item.url,
                    onSelectFile: onSelectFile
                )
            } label: {
                HStack(spacing: 4) {
                    // 文件图标
                    Image(systemName: iconName(for: item))
                        .font(.system(size: 10))
                        .foregroundColor(iconColor(for: item))

                    // 文件名
                    Text(item.name)
                        .font(.system(size: 11, weight: isLastItem ? .semibold : .regular))
                        .foregroundColor(
                            isLastItem
                                ? AppUI.Color.semantic.textPrimary
                                : AppUI.Color.semantic.textSecondary
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hoverBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            isMenuVisible ? AppUI.Color.semantic.primary.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(
                maxWidth: isHovering || isLastItem ? nil : truncatedCrumbWidth,
                alignment: .leading
            )
            .mask(
                LinearGradient(
                    gradient: Gradient(
                        stops: truncatedCrumbWidth == nil || isHovering
                            ? [.init(color: .black, location: 0), .init(color: .black, location: 1)]
                            : [.init(color: .black, location: 0), .init(color: .black, location: 0.8), .init(color: .clear, location: 1)]
                    ),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipped()
            .onHover { hover in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hover
                }
            }
            .onChange(of: truncatedCrumbWidth) { _, _ in
                // 截断状态变化时不做额外处理
            }

            // 分隔箭头
            if !isLastItem {
                chevronView
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Chevron

    /// 分隔箭头：hover 时显示上下箭头（表示可弹出菜单），否则显示右箭头
    @ViewBuilder
    private var chevronView: some View {
        HStack(spacing: 0) {
            if isHovering {
                // 上下箭头（表示可点击弹出菜单）
                VStack(spacing: 1) {
                    Image(systemName: "chevron.up")
                    Image(systemName: "chevron.down")
                }
                .font(.system(size: 6, weight: .bold, design: .default))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
                .padding(.top, 0.5)
            } else {
                // 右箭头
                Image(systemName: "chevron.compact.right")
                    .font(.system(size: 9, weight: .medium, design: .default))
                    .foregroundStyle(AppUI.Color.semantic.textTertiary)
                    .scaleEffect(x: 1.30, y: 1.0, anchor: .center)
                    .imageScale(.large)
            }
        }
        .padding(.trailing, 2)
    }

    // MARK: - Hover Background

    /// Hover 时的背景色
    private var hoverBackground: Color {
        guard isHovering else { return .clear }
        return colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.04)
    }

    // MARK: - Icon Helpers

    /// 根据 breadcrumb item 获取图标名称
    private func iconName(for item: BreadcrumbItem) -> String {
        if item.isDirectory {
            return "folder.fill"
        }
        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js": return "doc.text"
        case "ts": return "doc.text"
        case "tsx", "jsx": return "doc.text"
        case "py": return "doc.text"
        case "md", "mdx": return "doc.text"
        case "json": return "doc.text"
        case "yaml", "yml": return "doc.text"
        case "toml": return "doc.text"
        case "xml", "html": return "doc.text"
        case "css", "scss", "less": return "doc.text"
        case "java": return "doc.text"
        case "kt": return "doc.text"
        case "go": return "doc.text"
        case "rs": return "doc.text"
        case "c", "h": return "doc.text"
        case "cpp", "hpp", "cc": return "doc.text"
        case "m", "mm": return "doc.text"
        case "sh", "bash", "zsh": return "terminal"
        case "sql": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return "photo"
        case "pdf": return "doc.richtext"
        case "txt": return "doc.plaintext"
        case "xcodeproj", "xcworkspace": return "hammer"
        case "entitlements", "plist": return "gearshape"
        case "xcstrings": return "text.bubble"
        case "resolved": return "doc.text"
        default: return "doc"
        }
    }

    /// 根据 breadcrumb item 获取图标颜色
    private func iconColor(for item: BreadcrumbItem) -> Color {
        if item.isDirectory {
            return Color.blue
        }
        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "swift": return Color.orange
        case "js", "jsx": return Color.yellow
        case "ts", "tsx": return Color.blue
        case "py": return Color.green
        case "json": return Color.orange
        case "yaml", "yml", "toml": return Color.orange
        case "md", "mdx": return Color.blue
        case "html": return Color.orange
        case "css", "scss": return Color.purple
        case "java": return Color.red
        case "go": return Color.cyan
        case "rs": return Color.orange
        case "sh", "bash", "zsh": return Color.green
        default: return AppUI.Color.semantic.textSecondary
        }
    }
}

// MARK: - Breadcrumb Menu Content

/// 面包屑下拉菜单内容
/// 显示同级文件/文件夹列表，参考 CodeEdit EditorJumpBarMenu
struct BreadcrumbMenuContent: View {

    let siblings: [BreadcrumbSibling]
    let currentURL: URL
    let onSelectFile: (URL) -> Void

    var body: some View {
        // 按「目录在前，文件在后」分组
        let directories = siblings.filter(\.isDirectory)
        let files = siblings.filter { !$0.isDirectory }

        if !directories.isEmpty {
            Section {
                ForEach(directories) { sibling in
                    BreadcrumbMenuRow(
                        sibling: sibling,
                        isCurrent: sibling.url == currentURL,
                        onSelectFile: onSelectFile
                    )
                }
            }
        }

        if !files.isEmpty {
            if !directories.isEmpty {
                Divider()
            }
            Section {
                ForEach(files) { sibling in
                    BreadcrumbMenuRow(
                        sibling: sibling,
                        isCurrent: sibling.url == currentURL,
                        onSelectFile: onSelectFile
                    )
                }
            }
        }
    }
}

// MARK: - Breadcrumb Menu Row

/// 面包屑菜单行
/// 显示文件/文件夹图标和名称，支持点击跳转
struct BreadcrumbMenuRow: View {

    let sibling: BreadcrumbSibling
    let isCurrent: Bool
    let onSelectFile: (URL) -> Void

    var body: some View {
        Button {
            onSelectFile(sibling.url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 11))
                    .foregroundColor(iconColor)
                    .frame(width: 14)

                Text(sibling.name)
                    .font(.system(size: 12))

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.primary)
                }
            }
        }
    }

    private var iconName: String {
        if sibling.isDirectory {
            return "folder.fill"
        }
        let ext = sibling.url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js": return "doc.text"
        case "ts": return "doc.text"
        case "tsx", "jsx": return "doc.text"
        case "py": return "doc.text"
        case "md", "mdx": return "doc.text"
        case "json": return "doc.text"
        case "yaml", "yml": return "doc.text"
        case "toml": return "doc.text"
        case "xml", "html": return "doc.text"
        case "css", "scss", "less": return "doc.text"
        case "java": return "doc.text"
        case "kt": return "doc.text"
        case "go": return "doc.text"
        case "rs": return "doc.text"
        case "c", "h": return "doc.text"
        case "cpp", "hpp", "cc": return "doc.text"
        case "m", "mm": return "doc.text"
        case "sh", "bash", "zsh": return "terminal"
        case "sql": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return "photo"
        case "pdf": return "doc.richtext"
        case "txt": return "doc.plaintext"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        if sibling.isDirectory {
            return Color.blue
        }
        let ext = sibling.url.pathExtension.lowercased()
        switch ext {
        case "swift": return Color.orange
        case "js", "jsx": return Color.yellow
        case "ts", "tsx": return Color.blue
        case "py": return Color.green
        case "json": return Color.orange
        case "yaml", "yml", "toml": return Color.orange
        case "md", "mdx": return Color.blue
        case "html": return Color.orange
        case "css", "scss": return Color.purple
        case "java": return Color.red
        case "go": return Color.cyan
        case "rs": return Color.orange
        case "sh", "bash", "zsh": return Color.green
        default: return .secondary
        }
    }
}
