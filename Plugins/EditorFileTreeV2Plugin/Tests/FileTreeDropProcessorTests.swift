import XCTest
@testable import EditorFileTreeV2Plugin

/// FileTreeDropProcessor 的单元测试
///
/// 覆盖 `FileTreeCollectionViewController.handleDropFiles` 拆出来的纯函数，
/// 验证：
/// 1. 各种拒绝路径（开关关闭 / 非目录 / 空 sources / 全部失败）
/// 2. 正常成功路径下返回的 pairs 与 affectedParents 集合
/// 3. 嵌套子项被 topLevelURLs 过滤
/// 4. 注入的 isTargetDirectory / moveItem 函数被正确调用
@MainActor
final class FileTreeDropProcessorTests: XCTestCase {

    // MARK: - Rejected Paths

    func testProcessReturnsRejectedWhenDisabled() {
        let target = URL(fileURLWithPath: "/project/dst")
        let sources = [URL(fileURLWithPath: "/project/a.txt")]

        let result = FileTreeDropProcessor.process(
            enabled: false,
            targetURL: target,
            sourceURLs: sources,
            isTargetDirectory: { _ in true },
            moveItem: { _, _ in nil }
        )

        if case .moved = result {
            XCTFail("Disabled flag should reject the drop")
        }
    }

    func testProcessReturnsRejectedWhenTargetIsNotDirectory() {
        let target = URL(fileURLWithPath: "/project/dst.txt")
        let sources = [URL(fileURLWithPath: "/project/a.txt")]

        let result = FileTreeDropProcessor.process(
            enabled: true,
            targetURL: target,
            sourceURLs: sources,
            isTargetDirectory: { _ in false },
            moveItem: { _, _ in URL(fileURLWithPath: "/project/dst.txt") }
        )

        if case .moved = result {
            XCTFail("Non-directory target should be rejected")
        }
    }

    func testProcessReturnsRejectedWhenSourceURLsIsEmpty() {
        let target = URL(fileURLWithPath: "/project/dst")

        let result = FileTreeDropProcessor.process(
            enabled: true,
            targetURL: target,
            sourceURLs: [],
            isTargetDirectory: { _ in true },
            moveItem: { _, _ in nil }
        )

        if case .moved = result {
            XCTFail("Empty source list should be rejected")
        }
    }

    func testProcessReturnsRejectedWhenAllMoveFail() {
        let target = URL(fileURLWithPath: "/project/dst")
        let sources = [
            URL(fileURLWithPath: "/project/a.txt"),
            URL(fileURLWithPath: "/project/b.txt")
        ]

        let result = FileTreeDropProcessor.process(
            enabled: true,
            targetURL: target,
            sourceURLs: sources,
            isTargetDirectory: { _ in true },
            moveItem: { _, _ in nil } // every move returns nil → no success
        )

        if case .moved = result {
            XCTFail("All-failed move should be rejected")
        }
    }

    // MARK: - Happy Path

    func testProcessReturnsMovedPairsOnSuccess() {
        let target = URL(fileURLWithPath: "/project/dst")
        let sourceA = URL(fileURLWithPath: "/project/a.txt")
        let sourceB = URL(fileURLWithPath: "/project/b.txt")
        let sources = [sourceA, sourceB]
        let expectedA = target.appendingPathComponent("a.txt")
        let expectedB = target.appendingPathComponent("b.txt")

        let result = FileTreeDropProcessor.process(
            enabled: true,
            targetURL: target,
            sourceURLs: sources,
            isTargetDirectory: { _ in true },
            moveItem: { srcPath, destPath in
                let fileName = URL(fileURLWithPath: srcPath).lastPathComponent
                let newURL = URL(fileURLWithPath: destPath).appendingPathComponent(fileName)
                return newURL
            }
        )

        guard case .moved(let pairs, let affectedParents) = result else {
            XCTFail("Expected .moved, got \(result)")
            return
        }
        
        XCTAssertEqual(pairs.count, 2)
        XCTAssertTrue(pairs.contains(where: { $0.old == sourceA && $0.new == expectedA }))
        XCTAssertTrue(pairs.contains(where: { $0.old == sourceB && $0.new == expectedB }))

        // affectedParents 应包含 target 和两个 source 的 parent（都是 /project）
        // 注意：deletingLastPathComponent() 会保留尾部斜杠，需要用 standardizedFileURL 标准化
        XCTAssertTrue(affectedParents.contains(target.standardizedFileURL))
        XCTAssertTrue(affectedParents.contains(sourceA.deletingLastPathComponent().standardizedFileURL))
        XCTAssertEqual(affectedParents.count, 2)
    }

    func testProcessSkipsMoveThatReturnsNil() {
        let target = URL(fileURLWithPath: "/project/dst")
        let sourceA = URL(fileURLWithPath: "/project/a.txt")
        let sourceB = URL(fileURLWithPath: "/project/b.txt")
        let expectedA = target.appendingPathComponent("a.txt")

        let result = FileTreeDropProcessor.process(
            enabled: true,
            targetURL: target,
            sourceURLs: [sourceA, sourceB],
            isTargetDirectory: { _ in true },
            moveItem: { src, _ in
                src == sourceA.path ? expectedA : nil
            }
        )

        guard case .moved(let pairs, _) = result else {
            XCTFail("Expected .moved (partial success), got \(result)")
            return
        }
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.old, sourceA)
        XCTAssertEqual(pairs.first?.new, expectedA)
    }

    func testProcessSkipsNoOpMove() {
        // 模拟 moveItem 返回了与 sourcePath 相同的 URL（FileTreeFacade.moveItem 在
        // 源 == 目标目录的特殊情形下可能返回原 URL；这里验证 processor 也会忽略这种 no-op）。
        let target = URL(fileURLWithPath: "/project/dst")
        let source = URL(fileURLWithPath: "/project/dst/source.txt")

        let result = FileTreeDropProcessor.process(
            enabled: true,
            targetURL: target,
            sourceURLs: [source],
            isTargetDirectory: { _ in true },
            moveItem: { src, _ in URL(fileURLWithPath: src) } // 返回原 URL
        )

        if case .moved = result {
            XCTFail("No-op move (new == old) should be rejected")
        }
    }

    // MARK: - Nested Subset Filtering

    func testProcessDropsNestedChildWhenParentAlsoSelected() {
        // 模拟用户把 /project/dir 和 /project/dir/inner.txt 一起拖到 /project/dst。
        // topLevelURLs 应该只保留 /project/dir，inner.txt 不应该被独立处理。
        let target = URL(fileURLWithPath: "/project/dst")
        let parent = URL(fileURLWithPath: "/project/dir")
        let child = URL(fileURLWithPath: "/project/dir/inner.txt")
        let expectedParent = target.appendingPathComponent("dir")

        let result = FileTreeDropProcessor.process(
            enabled: true,
            targetURL: target,
            sourceURLs: [parent, child],
            isTargetDirectory: { _ in true },
            moveItem: { src, _ in
                src == parent.path ? expectedParent :
                src == child.path ? URL(fileURLWithPath: "/should/not/reach") : nil
            }
        )

        guard case .moved(let pairs, _) = result else {
            XCTFail("Expected .moved, got \(result)")
            return
        }
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.old, parent)
    }

    // MARK: - Affected Parents Collection

    func testProcessCollectsAllAffectedParents() {
        // 三个 source 来自不同父目录，验证 affectedParents 聚合正确。
        let target = URL(fileURLWithPath: "/project/dst")
        let s1 = URL(fileURLWithPath: "/project/A/a.txt")
        let s2 = URL(fileURLWithPath: "/project/B/b.txt")
        let s3 = URL(fileURLWithPath: "/project/C/c.txt")
        let sources = [s1, s2, s3]
        
        let result = FileTreeDropProcessor.process(
            enabled: true,
            targetURL: target,
            sourceURLs: sources,
            isTargetDirectory: { _ in true },
            moveItem: { srcPath, destPath in
                let fileName = URL(fileURLWithPath: srcPath).lastPathComponent
                return URL(fileURLWithPath: destPath).appendingPathComponent(fileName)
            }
        )
        
        guard case .moved(_, let affectedParents) = result else {
            XCTFail("Expected .moved, got \(result)")
            return
        }
        XCTAssertEqual(affectedParents.count, 4) // target + 3 source parents
        XCTAssertTrue(affectedParents.contains(target.standardizedFileURL))
        XCTAssertTrue(affectedParents.contains(s1.deletingLastPathComponent().standardizedFileURL))
        XCTAssertTrue(affectedParents.contains(s2.deletingLastPathComponent().standardizedFileURL))
        XCTAssertTrue(affectedParents.contains(s3.deletingLastPathComponent().standardizedFileURL))
    }
    
    func testProcessAffectedParentsDedupesWhenSourceSharesTargetParent() {
        // 两个 source 在同一个父目录，验证 affectedParents 去重
        let target = URL(fileURLWithPath: "/project/dst")
        let s1 = URL(fileURLWithPath: "/project/a.txt")
        let s2 = URL(fileURLWithPath: "/project/b.txt")
        
        let result = FileTreeDropProcessor.process(
            enabled: true,
            targetURL: target,
            sourceURLs: [s1, s2],
            isTargetDirectory: { _ in true },
            moveItem: { srcPath, destPath in
                let fileName = URL(fileURLWithPath: srcPath).lastPathComponent
                return URL(fileURLWithPath: destPath).appendingPathComponent(fileName)
            }
        )
        
        guard case .moved(_, let affectedParents) = result else {
            XCTFail("Expected .moved, got \(result)")
            return
        }
        // target (/project/dst) + source parent (/project) = 2
        XCTAssertEqual(affectedParents.count, 2)
        XCTAssertTrue(affectedParents.contains(target.standardizedFileURL))
        XCTAssertTrue(affectedParents.contains(s1.deletingLastPathComponent().standardizedFileURL))
    }
}
