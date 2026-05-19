import LumiPreviewKit
import XCTest
@testable import LumiPreviewKit

final class PreviewEntryGeneratorTests: XCTestCase {

    func test_generate_emitsExpectedSymbol() {
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview-1",
            title: "Demo",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Demo.swift"),
            lineNumber: 1,
            endLineNumber: 3,
            primaryTypeName: "Text",
            bodySource: "Text(\"hello\")",
            sourceText: nil
        )

        let source = LumiPreviewFacade.PreviewEntryGenerator.generate(for: discovery)

        XCTAssertTrue(source.contains("@_cdecl(\"lumi_preview_make_nsview\")"))
        XCTAssertTrue(source.contains("public func lumi_preview_make_nsview() -> UnsafeMutableRawPointer?"))
        XCTAssertTrue(source.contains("@_cdecl(\"lumi_preview_update_nsview\")"))
        XCTAssertTrue(source.contains("public func lumi_preview_update_nsview(_ existingView: UnsafeMutableRawPointer?) -> Bool"))
        XCTAssertTrue(source.contains("import AppKit"))
        XCTAssertTrue(source.contains("import SwiftUI"))
        XCTAssertTrue(source.contains("Text(\"hello\")"))
        XCTAssertTrue(source.contains("Unmanaged.passRetained(hosting).toOpaque()"))
    }

    func test_generate_indentsBodyToMatchTemplate() {
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview-1",
            title: "Multi-line",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Demo.swift"),
            lineNumber: 1,
            endLineNumber: 5,
            primaryTypeName: "VStack",
            bodySource: "VStack {\n    Text(\"a\")\n    Text(\"b\")\n}",
            sourceText: nil
        )

        let source = LumiPreviewFacade.PreviewEntryGenerator.generate(for: discovery)

        // 模板中 body 的缩进基线是 8 空格；首行至少应有 8 空格前缀。
        XCTAssertTrue(source.contains("        VStack {"))
        XCTAssertTrue(source.contains("            Text(\"a\")"))
    }

    func test_generate_handlesEmptyBody_byEmittingEmptyView() {
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview-1",
            title: "Empty",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Empty.swift"),
            lineNumber: 1,
            endLineNumber: 1,
            primaryTypeName: nil,
            bodySource: nil,
            sourceText: nil
        )

        let source = LumiPreviewFacade.PreviewEntryGenerator.generate(for: discovery)
        XCTAssertTrue(source.contains("EmptyView()"))
    }
}
