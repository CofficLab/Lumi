import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

// MARK: - Nav Path View

/// 面包屑路径视图
public struct NavPathView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing
    @ObservedObject private var service: EditorService

    public let fileURL: URL

    private var currentProjectPath: String {
        lumiCore.projectState?.currentProject?.path ?? ""
    }

    public init(fileURL: URL, service: EditorService, lumiCore: LumiCoreAccessing) {
        self.fileURL = fileURL
        self.service = service
        self.lumiCore = lumiCore
    }

    /// 面包屑路径段列表
    private var breadcrumbItems: [BreadcrumbItem] {
        // 标准化文件路径：解析符号链接、移除末尾斜杠
        let normalizedFile = fileURL.resolvingSymlinksInPath()
        let fullPath = normalizedFile.path
        let cleanFull = fullPath.hasSuffix("/") ? String(fullPath.dropLast()) : fullPath

        let rawProjectPath = currentProjectPath
        let trimmedProjectPath = rawProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedProjectPath.isEmpty {
            // 标准化项目路径
            let normalizedProject = URL(fileURLWithPath: trimmedProjectPath).resolvingSymlinksInPath()
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

                            NavComponent(
                                item: item,
                                isLastItem: isLast,
                                truncatedCrumbWidth: item.index == 0
                                    ? $firstCrumbWidth : $crumbWidth,
                                onSelectFile: { url in
                                    let rawProjectPath = currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !rawProjectPath.isEmpty else { return }
                                    guard NavHeaderView.isFile(url, inProjectPath: rawProjectPath) else {
                                        return
                                    }
                                    Task { @MainActor in
                                        await service.refreshProjectContext(for: currentProjectPath)
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
                recalculateTruncation()
            }
            .onChange(of: containerWidth) { _, _ in
                recalculateTruncation()
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
