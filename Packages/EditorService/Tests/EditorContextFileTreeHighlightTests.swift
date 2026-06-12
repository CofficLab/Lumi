#if canImport(XCTest)
import Foundation
import XCTest
@testable import EditorService

@MainActor
final class EditorContextFileTreeHighlightTests: XCTestCase {
    private func makeService() -> EditorService {
        EditorService(editorExtensionRegistry: EditorExtensionRegistry())
    }

    func testLegacyHighlightResolverKeepsStaleTreeSelectionAfterEditorNavigation() {
        let fileA = URL(fileURLWithPath: "/tmp/project/Sources/A.swift")
        let fileB = URL(fileURLWithPath: "/tmp/project/Sources/B.swift")

        let resolved = EditorFileTreeHighlightResolver.legacyResolve(
            highlighted: fileA,
            current: fileB
        )

        XCTAssertEqual(resolved, fileA)
        XCTAssertFalse(EditorFileTreeHighlightResolver.isSameFile(resolved, fileB))
    }

    func testEditorContextSyncsHighlightWhenEditorCurrentFileChanges() async {
        let service = makeService()
        let context = EditorContext(service: service)
        let fileA = URL(fileURLWithPath: "/tmp/project/Sources/A.swift")
        let fileB = URL(fileURLWithPath: "/tmp/project/Sources/B.swift")

        context.setFileTreeHighlightedFileURL(fileA)
        XCTAssertTrue(EditorFileTreeHighlightResolver.isSameFile(context.resolvedFileTreeHighlightURL(), fileA))

        service.state.testing_setCurrentFileURL(fileB)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertTrue(
            EditorFileTreeHighlightResolver.isSameFile(context.resolvedFileTreeHighlightURL(), fileB),
            "文件树高亮应跟随编辑器当前文件更新"
        )
        XCTAssertTrue(
            EditorFileTreeHighlightResolver.isSameFile(context.fileTreeHighlightedFileURL, fileB)
        )
    }

    func testAddToConversationPostsFileURLNotification() {
        let service = makeService()
        let context = EditorContext(service: service)
        let windowId = UUID()
        let fileURL = URL(fileURLWithPath: "/tmp/project/Sources/A.swift")
        let expectation = expectation(description: "addToChat notification")
        let observer = NotificationCenter.default.addObserver(
            forName: EditorContext.addToChatNotificationName,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?["fileURL"] as? String, fileURL.path)
            XCTAssertEqual(notification.userInfo?["windowId"] as? UUID, windowId)
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        context.addToConversation(fileURL: fileURL, windowId: windowId)
        wait(for: [expectation], timeout: 1)
    }

    func testTreeSelectionStillWorksBeforeEditorCurrentFileCatchesUp() {
        let service = makeService()
        let context = EditorContext(service: service)
        let fileA = URL(fileURLWithPath: "/tmp/project/Sources/A.swift")
        let fileB = URL(fileURLWithPath: "/tmp/project/Sources/B.swift")

        service.state.testing_setCurrentFileURL(fileB)
        context.setFileTreeHighlightedFileURL(fileA)

        XCTAssertTrue(
            EditorFileTreeHighlightResolver.isSameFile(context.resolvedFileTreeHighlightURL(), fileA),
            "用户点选文件树后，在编辑器完成切换前应保持树侧选中"
        )
    }
}
#endif
