import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1100：多文件拖放时单个源移动失败被静默跳过，
/// 处理器只返回成功 pairs，调用方无法区分「全部成功」与「部分失败」。
@Test("部分移动失败时必须上报失败源")
func partialDropFailureReportsFailedSources() {
    let target = URL(fileURLWithPath: "/Project/drop-target", isDirectory: true)
    let movedSource = URL(fileURLWithPath: "/Project/source-a/free.txt")
    let failedSource = URL(fileURLWithPath: "/Project/source-b/existing.txt")

    let result = FileTreeDropProcessor.process(
        enabled: true,
        targetURL: target,
        sourceURLs: [movedSource, failedSource],
        isTargetDirectory: { _ in true },
        moveItem: { sourcePath, _ in
            sourcePath == movedSource.path
                ? target.appendingPathComponent(movedSource.lastPathComponent)
                : nil
        }
    )

    switch result {
    case .rejected:
        Issue.record("部分成功不应被判定为 rejected")
    case .moved(let pairs, let failedSources, let affectedParents):
        #expect(pairs.count == 1)
        #expect(pairs.first?.old == movedSource)
        #expect(failedSources == [failedSource])
        #expect(affectedParents.contains(target.standardizedFileURL))
        #expect(
            affectedParents.contains(movedSource.deletingLastPathComponent().standardizedFileURL)
        )
        #expect(
            !affectedParents.contains(failedSource.deletingLastPathComponent().standardizedFileURL)
        )
    }
}

@Test("全部移动成功时失败源列表为空")
func successfulDropReportsNoFailedSources() {
    let target = URL(fileURLWithPath: "/Project/drop-target", isDirectory: true)
    let first = URL(fileURLWithPath: "/Project/source-a/first.txt")
    let second = URL(fileURLWithPath: "/Project/source-b/second.txt")

    let result = FileTreeDropProcessor.process(
        enabled: true,
        targetURL: target,
        sourceURLs: [first, second],
        isTargetDirectory: { _ in true },
        moveItem: { sourcePath, _ in
            target.appendingPathComponent(URL(fileURLWithPath: sourcePath).lastPathComponent)
        }
    )

    switch result {
    case .rejected:
        Issue.record("全部成功不应被判定为 rejected")
    case .moved(let pairs, let failedSources, _):
        #expect(pairs.count == 2)
        #expect(failedSources.isEmpty)
    }
}
