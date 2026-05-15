import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("EditorPreviewRefreshSignal")
struct EditorPreviewRefreshSignalTests {

    @Test("contentRevision 变化时信号变化")
    func contentRevisionChangeProducesDifferentSignal() {
        let url = URL(fileURLWithPath: "/tmp/Preview.swift")
        let before = LumiPreviewFacade.EditorPreviewRefreshSignal(fileURL: url, contentRevision: 1, saveRevision: 0)
        let after = LumiPreviewFacade.EditorPreviewRefreshSignal(fileURL: url, contentRevision: 2, saveRevision: 0)

        #expect(before != after)
    }

    @Test("saveRevision 变化时信号变化")
    func saveRevisionChangeProducesDifferentSignal() {
        let url = URL(fileURLWithPath: "/tmp/Preview.swift")
        let before = LumiPreviewFacade.EditorPreviewRefreshSignal(fileURL: url, contentRevision: 7, saveRevision: 1)
        let after = LumiPreviewFacade.EditorPreviewRefreshSignal(fileURL: url, contentRevision: 7, saveRevision: 2)

        #expect(before != after)
    }

    @Test("仅保存成功也会触发 refresh signal")
    func saveRevisionOnlyChangeTriggersRefresh() {
        let before = LumiPreviewFacade.EditorPreviewRefreshSignal(
            fileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            contentRevision: 7,
            saveRevision: 1
        )
        let after = LumiPreviewFacade.EditorPreviewRefreshSignal(
            fileURL: URL(fileURLWithPath: "/tmp/Preview.swift"),
            contentRevision: 7,
            saveRevision: 2
        )

        #expect(after.shouldTriggerRefresh(comparedTo: before))
    }

    @Test("标准化后的相同文件 URL 视为同一信号来源")
    func standardizedFileURLsCompareEqual() {
        let first = LumiPreviewFacade.EditorPreviewRefreshSignal(
            fileURL: URL(fileURLWithPath: "/tmp/demo/../demo/Preview.swift"),
            contentRevision: 3,
            saveRevision: 1
        )
        let second = LumiPreviewFacade.EditorPreviewRefreshSignal(
            fileURL: URL(fileURLWithPath: "/tmp/demo/Preview.swift"),
            contentRevision: 3,
            saveRevision: 1
        )

        #expect(first == second)
    }
}
