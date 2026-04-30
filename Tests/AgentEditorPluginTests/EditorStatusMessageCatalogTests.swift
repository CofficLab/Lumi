#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorStatusMessageCatalogTests: XCTestCase {
    func testSaveFailedIncludesDetailWhenPresent() {
        XCTAssertEqual(
            EditorStatusMessageCatalog.saveFailed("Permission denied"),
            "Save failed. Permission denied"
        )
    }

    func testLanguageFeatureUnavailableWrapsReason() {
        XCTAssertEqual(
            EditorStatusMessageCatalog.languageFeatureUnavailable(
                operation: "格式化文档",
                reason: "当前 Xcode 项目上下文还没有完成初始化。"
            ),
            "格式化文档 unavailable. 当前 Xcode 项目上下文还没有完成初始化。"
        )
    }
}
#endif
