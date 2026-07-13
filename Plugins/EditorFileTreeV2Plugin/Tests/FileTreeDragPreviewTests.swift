import XCTest
import SwiftUI
@testable import EditorFileTreeV2Plugin

/// FileTreeDragPreview 渲染 smoke test
///
/// 由于 SwiftUI 视图无法直接断言渲染结果（需要 ViewInspector 等三方库），
/// 这里只验证 `init` / `body` 求值不崩溃，且构造的参数被正确持有。
/// 视觉验收由 V1 已有的视图保证一致性。
@MainActor
final class FileTreeDragPreviewTests: XCTestCase {

    func testInitKeepsFileURLAndIsDirectory() {
        let url = URL(fileURLWithPath: "/project/main.swift")
        let preview = FileTreeDragPreview(fileURL: url, isDirectory: false)

        // 字段是 public 但不暴露 getter —— 通过 Mirror 反射验证持有
        let mirror = Mirror(reflecting: preview)
        let children = mirror.children.compactMap { $0.label }
        XCTAssertTrue(children.contains("fileURL"))
        XCTAssertTrue(children.contains("isDirectory"))
    }

    func testBodyEvaluationDoesNotCrashForFile() {
        let preview = FileTreeDragPreview(
            fileURL: URL(fileURLWithPath: "/project/main.swift"),
            isDirectory: false
        )
        // 求值 body 应不抛异常；返回类型是 opaque，无法直接断言，但至少不应崩溃。
        _ = preview.body
    }

    func testBodyEvaluationDoesNotCrashForDirectory() {
        let preview = FileTreeDragPreview(
            fileURL: URL(fileURLWithPath: "/project/Sources"),
            isDirectory: true
        )
        _ = preview.body
    }
}
