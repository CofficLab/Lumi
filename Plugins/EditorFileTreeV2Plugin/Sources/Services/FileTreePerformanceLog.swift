import Foundation
import os
import SuperLogKit

/// 文件树性能诊断日志。
///
/// 只记录聚合后的关键计数，避免滚动时逐行刷屏影响性能判断。
@MainActor
enum FileTreePerformanceLog: SuperLog {
    nonisolated static let emoji = "📈"
    nonisolated static var verbose: Bool { EditorFileTreeV2Plugin.verbose }
    nonisolated static let logger = EditorFileTreeV2Plugin.logger

    /// 性能日志总开关。定位完成后可改为 false，避免日常日志噪声。
    private static let enabled = true

    private static let reportInterval: TimeInterval = 1.0
    private static var lastBodyReportAt = Date()
    private static var lastLifecycleReportAt = Date()
    private static var lastHoverReportAt = Date()
    private static var lastTreeBodyReportAt = Date()

    private static var nodeBodyCount = 0
    private static var directoryBodyCount = 0
    private static var fileBodyCount = 0
    private static var expandedDirectoryBodyCount = 0
    private static var maxBodyDepth = 0
    private static var maxChildrenCount = 0

    private static var appearCount = 0
    private static var disappearCount = 0
    private static var trackedRowEstimate = 0
    private static var maxTrackedRowEstimate = 0

    private static var hoverChangeCount = 0
    private static var hoverEnterCount = 0
    private static var hoverExitCount = 0

    private static var treeBodyCount = 0

    static func recordTreeBody(projectPath: String, rootRefreshToken: Int, showsPackageDependencies: Bool) {
        guard enabled, verbose else { return }
        treeBodyCount += 1
        let now = Date()
        guard now.timeIntervalSince(lastTreeBodyReportAt) >= reportInterval else { return }
        logger.info("\(Self.t)PERF TreeBody count=\(treeBodyCount) rootRefreshToken=\(rootRefreshToken) hasProject=\(!projectPath.isEmpty) packageSection=\(showsPackageDependencies)")
        treeBodyCount = 0
        lastTreeBodyReportAt = now
    }

    static func recordNodeBody(
        url: URL,
        depth: Int,
        isDirectory: Bool,
        isExpanded: Bool,
        childrenCount: Int
    ) {
        guard enabled, verbose else { return }
        nodeBodyCount += 1
        if isDirectory {
            directoryBodyCount += 1
            if isExpanded { expandedDirectoryBodyCount += 1 }
        } else {
            fileBodyCount += 1
        }
        maxBodyDepth = max(maxBodyDepth, depth)
        maxChildrenCount = max(maxChildrenCount, childrenCount)

        let now = Date()
        guard now.timeIntervalSince(lastBodyReportAt) >= reportInterval else { return }
        logger.info("\(Self.t)PERF NodeBody count=\(nodeBodyCount) dirs=\(directoryBodyCount) files=\(fileBodyCount) expandedDirs=\(expandedDirectoryBodyCount) maxDepth=\(maxBodyDepth) maxChildren=\(maxChildrenCount) sample=\(url.lastPathComponent)")
        nodeBodyCount = 0
        directoryBodyCount = 0
        fileBodyCount = 0
        expandedDirectoryBodyCount = 0
        maxBodyDepth = 0
        maxChildrenCount = 0
        lastBodyReportAt = now
    }

    static func recordNodeAppear(url: URL, depth: Int, isDirectory: Bool) {
        guard enabled, verbose else { return }
        appearCount += 1
        trackedRowEstimate += 1
        maxTrackedRowEstimate = max(maxTrackedRowEstimate, trackedRowEstimate)
        reportLifecycleIfNeeded(sampleURL: url, sampleDepth: depth, sampleIsDirectory: isDirectory)
    }

    static func recordNodeDisappear(url: URL, depth: Int, isDirectory: Bool) {
        guard enabled, verbose else { return }
        disappearCount += 1
        trackedRowEstimate = max(0, trackedRowEstimate - 1)
        reportLifecycleIfNeeded(sampleURL: url, sampleDepth: depth, sampleIsDirectory: isDirectory)
    }

    static func recordHoverChange(url: URL, depth: Int, hovering: Bool) {
        guard enabled, verbose else { return }
        hoverChangeCount += 1
        if hovering {
            hoverEnterCount += 1
        } else {
            hoverExitCount += 1
        }

        let now = Date()
        guard now.timeIntervalSince(lastHoverReportAt) >= reportInterval else { return }
        logger.info("\(Self.t)PERF Hover changes=\(hoverChangeCount) enter=\(hoverEnterCount) exit=\(hoverExitCount) sample=\(url.lastPathComponent) depth=\(depth)")
        hoverChangeCount = 0
        hoverEnterCount = 0
        hoverExitCount = 0
        lastHoverReportAt = now
    }

    static func recordLoadChildrenFinished(url: URL, depth: Int, count: Int, elapsedMilliseconds: Double) {
        guard enabled, verbose else { return }
        let rounded = Int(elapsedMilliseconds.rounded())
        logger.info("\(Self.t)PERF LoadChildren path=\(url.lastPathComponent) depth=\(depth) count=\(count) elapsedMs=\(rounded)")
    }

    static func recordLoadChildrenFailed(url: URL, depth: Int, elapsedMilliseconds: Double, error: Error) {
        guard enabled, verbose else { return }
        let rounded = Int(elapsedMilliseconds.rounded())
        logger.warning("\(Self.t)PERF LoadChildrenFailed path=\(url.lastPathComponent) depth=\(depth) elapsedMs=\(rounded) error=\(error.localizedDescription)")
    }

    private static func reportLifecycleIfNeeded(sampleURL: URL, sampleDepth: Int, sampleIsDirectory: Bool) {
        let now = Date()
        guard now.timeIntervalSince(lastLifecycleReportAt) >= reportInterval else { return }
        logger.info("\(Self.t)PERF Lifecycle appear=\(appearCount) disappear=\(disappearCount) trackedEstimate=\(trackedRowEstimate) maxTracked=\(maxTrackedRowEstimate) sample=\(sampleURL.lastPathComponent) depth=\(sampleDepth) dir=\(sampleIsDirectory)")
        appearCount = 0
        disappearCount = 0
        maxTrackedRowEstimate = trackedRowEstimate
        lastLifecycleReportAt = now
    }
}