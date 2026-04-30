#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorQuickOpenControllerTests: XCTestCase {
    func testParseRecognizesScopedPrefixes() {
        let controller = EditorQuickOpenController(fileSearch: { _, _, _ in [] })

        XCTAssertEqual(controller.parse("@ renderer").scope, .documentSymbols)
        XCTAssertEqual(controller.parse("@ renderer").searchText, "renderer")
        XCTAssertEqual(controller.parse("# AppState").scope, .workspaceSymbols)
        XCTAssertEqual(controller.parse(":12:7").scope, .line)
        XCTAssertEqual(controller.parse(":12:7").line, 12)
        XCTAssertEqual(controller.parse(":12:7").column, 7)
        XCTAssertEqual(controller.parse("> rename").scope, .commands)
        XCTAssertEqual(controller.parse("settings").scope, .files)
    }

    func testFileSuggestionsPreferRecentOpenEditorsWhenQueryIsEmpty() {
        let controller = EditorQuickOpenController(fileSearch: { _, _, _ in [] })
        let recentURL = URL(fileURLWithPath: "/tmp/Recent.swift")
        let olderURL = URL(fileURLWithPath: "/tmp/Older.swift")
        let openEditors = [
            EditorOpenEditorItem(
                sessionID: UUID(),
                fileURL: olderURL,
                title: "Older.swift",
                isDirty: false,
                isPinned: false,
                groupID: nil,
                groupIndex: nil,
                isInActiveGroup: false,
                isActive: false,
                recentActivationRank: 2
            ),
            EditorOpenEditorItem(
                sessionID: UUID(),
                fileURL: recentURL,
                title: "Recent.swift",
                isDirty: false,
                isPinned: false,
                groupID: nil,
                groupIndex: nil,
                isInActiveGroup: true,
                isActive: true,
                recentActivationRank: 0
            )
        ]

        let items = controller.fileSuggestions(
            for: controller.parse(""),
            context: .init(projectRootPath: nil, currentFileURL: recentURL),
            openEditors: openEditors,
            onOpenFile: { _, _, _ in }
        )

        XCTAssertEqual(items.first?.title, "Recent.swift")
        XCTAssertEqual(items.first?.sectionTitle, "Recent Files")
    }

    func testFileSuggestionsAddParentBadgeForDuplicateFileNames() {
        let controller = EditorQuickOpenController(
            fileSearch: { _, _, _ in
                [
                    FileResult(
                        name: "Config.swift",
                        path: "/tmp/Sources/FeatureA/Config.swift",
                        relativePath: "Sources/FeatureA/Config.swift",
                        isDirectory: false,
                        score: 90
                    ),
                    FileResult(
                        name: "Config.swift",
                        path: "/tmp/Sources/FeatureB/Config.swift",
                        relativePath: "Sources/FeatureB/Config.swift",
                        isDirectory: false,
                        score: 85
                    )
                ]
            }
        )

        let items = controller.fileSuggestions(
            for: controller.parse("config"),
            context: .init(projectRootPath: "/tmp", currentFileURL: nil),
            openEditors: [],
            onOpenFile: { _, _, _ in }
        )

        XCTAssertEqual(items.map(\.badge), ["FeatureA", "FeatureB"])
    }

    func testLineSuggestionsProduceLineJumpAction() {
        let controller = EditorQuickOpenController(fileSearch: { _, _, _ in [] })
        let fileURL = URL(fileURLWithPath: "/tmp/AppView.swift")
        var openedTarget: CursorPosition?

        let items = controller.lineSuggestions(
            for: controller.parse(":18:3"),
            currentFileURL: fileURL,
            fileName: "AppView.swift",
            relativeFilePath: "Sources/AppView.swift",
            onOpenFile: { _, target, _ in
                openedTarget = target
            }
        )

        XCTAssertEqual(items.first?.title, "Line 18, Column 3")
        items.first?.action()
        XCTAssertEqual(openedTarget?.start.line, 18)
        XCTAssertEqual(openedTarget?.start.column, 3)
    }

    func testFileSuggestionsPrioritizeEngineeringProjectFiles() {
        let controller = EditorQuickOpenController(
            fileSearch: { _, _, _ in
                [
                    FileResult(
                        name: "AppDelegate.swift",
                        path: "/tmp/AppDelegate.swift",
                        relativePath: "AppDelegate.swift",
                        isDirectory: false,
                        score: 80
                    ),
                    FileResult(
                        name: "Debug.xcconfig",
                        path: "/tmp/Config/Debug.xcconfig",
                        relativePath: "Config/Debug.xcconfig",
                        isDirectory: false,
                        score: 80
                    )
                ]
            }
        )

        let items = controller.fileSuggestions(
            for: controller.parse("debug"),
            context: .init(projectRootPath: "/tmp", currentFileURL: nil),
            openEditors: [],
            onOpenFile: { _, _, _ in }
        )

        XCTAssertEqual(items.first?.title, "Debug.xcconfig")
        XCTAssertEqual(items.first?.systemImage, "slider.horizontal.3")
    }
}
#endif
