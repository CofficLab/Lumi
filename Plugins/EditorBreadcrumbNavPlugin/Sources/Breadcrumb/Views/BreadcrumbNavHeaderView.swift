import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

/// 面包屑导航头部视图
///
/// 在编辑器面板中显示当前文件的路径面包屑导航。
/// 仅显示文件路径段，符号面包屑由 EditorStickySymbolBarPlugin 负责。
public struct BreadcrumbNavHeaderView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @ObservedObject private var service: EditorService
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public init(service: EditorService) {
        self.service = service
    }

    public var body: some View {
        AppToolbarContainer(
            height: AppPanelChromeMetrics.breadcrumbBarHeight,
            showsBottomBorder: true,
            bottomShadowLevel: .xxxl,
            backgroundStyle: .custom(theme.textTertiary.opacity(0.035)),
            padding: EdgeInsets(
                top: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                leading: AppPanelChromeMetrics.breadcrumbHorizontalPadding,
                bottom: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                trailing: AppPanelChromeMetrics.breadcrumbHorizontalPadding
            )
        ) {
            if let fileURL = service.files.currentFileURL,
               projectVM.isProjectSelected,
               isFileInCurrentProject(fileURL) {
                breadcrumbPath(fileURL: fileURL)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: AppPanelChromeMetrics.breadcrumbContentHeight, alignment: .center)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func breadcrumbPath(fileURL: URL) -> some View {
        BreadcrumbNavPathView(fileURL: fileURL, service: service)
    }

    private func isFileInCurrentProject(_ fileURL: URL) -> Bool {
        let projectPath = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.isFile(fileURL, inProjectPath: projectPath)
    }

    static func isFile(_ fileURL: URL, inProjectPath rawProjectPath: String) -> Bool {
        let projectPath = rawProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else { return false }
        let projectRoot = URL(fileURLWithPath: projectPath).standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        return filePath == projectRoot || filePath.hasPrefix(projectRoot + "/")
    }
}

// MARK: - Breadcrumb Nav Path View

/// 面包屑路径视图
public struct BreadcrumbNavPathView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM
    @ObservedObject private var service: EditorService
    @LumiMotionPreferenceReader private var motionPreference

    public let fileURL: URL

    public init(fileURL: URL, service: EditorService) {
        self.fileURL = fileURL
        self.service = service
    }

    /// 面包屑路径段列表
    private var breadcrumbItems: [BreadcrumbItem] {
        // 标准化文件路径：解析符号链接、移除末尾斜杠
        let normalizedFile = fileURL.resolvingSymlinksInPath()
        let fullPath = normalizedFile.path
        let cleanFull = fullPath.hasSuffix("/") ? String(fullPath.dropLast()) : fullPath

        if let rawProjectPath = Optional(projectVM.currentProjectPath).flatMap({ path -> String? in
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }) {
            // 标准化项目路径
            let normalizedProject = URL(fileURLWithPath: rawProjectPath).resolvingSymlinksInPath()
            let projectPath = normalizedProject.path
            let cleanProject = projectPath.hasSuffix("/") ? String(projectPath.dropLast()) : projectPath

            if cleanFull.hasPrefix(cleanProject + "/") {
                let relative = String(cleanFull.dropFirst(cleanProject.count + 1))
                let segments = relative.split(separator: "/").map(String.init)
                var runningPath = cleanProject

                return segments.enumerated().map { index, segment in
                    runningPath += "/" + segment
                    let segmentURL = URL(fileURLWithPath: runningPath)
                    let isDirectory =
                        (try? segmentURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory)
                        ?? false
                    return BreadcrumbItem(
                        index: index, name: segment, url: segmentURL, isDirectory: isDirectory)
                }
            }
        }

        // 降级方案：按完整路径解析
        let segments = cleanFull.split(separator: "/").map(String.init)
        var runningPath = ""

        return segments.enumerated().map { index, segment in
            runningPath += "/" + segment
            let segmentURL = URL(fileURLWithPath: runningPath)
            let isDirectory =
                (try? segmentURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return BreadcrumbItem(
                index: index, name: segment, url: segmentURL, isDirectory: isDirectory)
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

    public var body: some View {
        HStack(spacing: 0) {
            // 面包屑路径
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    if !breadcrumbItems.isEmpty {
                        ForEach(breadcrumbItems) { item in
                            let isLast = item.index == breadcrumbItems.count - 1

                            BreadcrumbNavComponent(
                                item: item,
                                isLastItem: isLast,
                                truncatedCrumbWidth: item.index == 0
                                    ? $firstCrumbWidth : $crumbWidth,
                                onSelectFile: { url in
                                    let rawProjectPath = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !rawProjectPath.isEmpty else { return }
                                    guard BreadcrumbNavHeaderView.isFile(url, inProjectPath: rawProjectPath) else {
                                        return
                                    }
                                    Task { @MainActor in
                                        await service.refreshProjectContext(for: projectVM.currentProjectPath)
                                        service.sessions.open(at: url)
                                    }
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
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            containerWidth = proxy.size.width
                        }
                        .onChange(of: proxy.size.width) { _, newValue in
                            containerWidth = newValue
                        }
                }
            )
            .onChange(of: textWidth) { _, _ in
                LumiMotion.animate(LumiMotion.enabled(LumiMotion.selection, preference: motionPreference)) {
                    recalculateTruncation()
                }
            }
            .onChange(of: containerWidth) { _, _ in
                LumiMotion.animate(LumiMotion.enabled(LumiMotion.selection, preference: motionPreference)) {
                    recalculateTruncation()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
    }

    // MARK: - Truncation Logic

    /// 智能截断策略：当面包屑总宽度超过容器宽度时，截断非首段路径
    private func recalculateTruncation() {
        let itemCount = breadcrumbItems.count
        guard itemCount > 0 else {
            crumbWidth = nil
            firstCrumbWidth = nil
            return
        }

        let minWidth: CGFloat = 60
        let snapThreshold: CGFloat = 30
        let maxWidth: CGFloat = textWidth / CGFloat(itemCount)
        let exponent: CGFloat = 5.0
        var betweenWidth: CGFloat = 0.0

        if textWidth >= containerWidth {
            let scale = max(0, min(1, containerWidth / textWidth))
            betweenWidth = floor((minWidth + (maxWidth - minWidth) * pow(scale, exponent)))
            if betweenWidth < minWidth {
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

            let crumbSpacingMultiplier: CGFloat = 1.5
            let availableForFirst = containerWidth - usedWidth * crumbSpacingMultiplier
            if availableForFirst < snapThreshold {
                firstCrumbWidth = minWidth
            } else {
                firstCrumbWidth = availableForFirst
            }
        }
    }
}

// MARK: - Breadcrumb Nav Component

/// 单个面包屑路径段组件
public struct BreadcrumbNavComponent: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let item: BreadcrumbItem
    public let isLastItem: Bool
    @Binding var truncatedCrumbWidth: CGFloat?
    public let onSelectFile: (URL) -> Void

    @LumiMotionPreferenceReader private var motionPreference
    @State private var isHovering = false
    @State private var isSiblingPopoverPresented = false

    public var body: some View {
        HStack(spacing: 0) {
            Button {
                isSiblingPopoverPresented.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: BreadcrumbNavIconStyle.iconName(for: item))
                        .font(.appMicro)
                        .foregroundColor(BreadcrumbNavIconStyle.iconColor(for: item, theme: theme))

                    Text(item.name)
                        .font(isLastItem ? .appMicroEmphasized : .appMicro)
                        .foregroundColor(isLastItem ? theme.textPrimary : theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .appSurface(
                    style: .custom(hoverBackground),
                    cornerRadius: 4,
                    borderColor: isSiblingPopoverPresented ? theme.primary.opacity(0.3) : Color.clear
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isSiblingPopoverPresented, arrowEdge: .bottom) {
                BreadcrumbMenuContent(
                    siblings: item.siblings,
                    currentURL: item.url,
                    onSelectFile: { url in
                        isSiblingPopoverPresented = false
                        onSelectFile(url)
                    }
                )
                .frame(minWidth: 220)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: 200)
            .frame(
                maxWidth: isHovering || isLastItem ? nil : truncatedCrumbWidth,
                alignment: .leading
            )
            .mask(
                LinearGradient(
                    gradient: Gradient(
                        stops: truncatedCrumbWidth == nil || isHovering
                            ? [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 1),
                            ]
                            : [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.8),
                                .init(color: .clear, location: 1),
                            ]
                    ),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipped()
            .onHover { hover in
                LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                    isHovering = hover
                }
            }

            // 分隔箭头
            if !isLastItem {
                chevronView
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Chevron

    @ViewBuilder
    private var chevronView: some View {
        HStack(spacing: 0) {
            if isHovering {
                VStack(spacing: 1) {
                    Image(systemName: "chevron.up")
                    Image(systemName: "chevron.down")
                }
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textTertiary)
                .padding(.top, 0.5)
            } else {
                Image(systemName: "chevron.compact.right")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)
                    .scaleEffect(x: 1.30, y: 1.0, anchor: .center)
                    .imageScale(.large)
            }
        }
        .padding(.trailing, 2)
    }

    // MARK: - Hover Background

    private var hoverBackground: Color {
        guard isHovering else { return .clear }
        return theme.textPrimary.opacity(0.06)
    }

}

// MARK: - Breadcrumb Menu Content

public struct BreadcrumbMenuContent: View {
    public let siblings: [BreadcrumbSibling]
    public let currentURL: URL
    public let onSelectFile: (URL) -> Void

    public var body: some View {
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

public struct BreadcrumbMenuRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let sibling: BreadcrumbSibling
    public let isCurrent: Bool
    public let onSelectFile: (URL) -> Void

    public var body: some View {
        Button {
            onSelectFile(sibling.url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.appMicro)
                    .foregroundColor(iconColor)
                    .frame(width: 14)

                Text(sibling.name)
                    .font(.appCaption)

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.primary)
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
        case "md", "mdx": return "doc.text"
        case "json": return "doc.text"
        case "yaml", "yml", "toml": return "doc.text"
        case "xml", "html": return "doc.text"
        case "css", "scss", "less": return "doc.text"
        case "js", "jsx": return "doc.text"
        case "ts", "tsx": return "doc.text"
        case "py": return "doc.text"
        case "java": return "doc.text"
        case "kt": return "doc.text"
        case "go": return "doc.text"
        case "rs": return "doc.text"
        case "c", "h": return "doc.text"
        case "cpp", "hpp", "cc": return "doc.text"
        case "m", "mm": return "doc.text"
        case "sh", "bash", "zsh": return "terminal"
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
        default: return theme.textSecondary
        }
    }
}
