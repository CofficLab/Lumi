import XCTest
@testable import WebServerKit

final class RouteMatcherTests: XCTestCase {
    func testLiteralExactMatch() {
        let matcher = RouteMatcher(template: "/api/health")
        XCTAssertEqual(matcher.match("/api/health"), [:])
        XCTAssertNil(matcher.match("/api/health/extra"))
        XCTAssertNil(matcher.match("/api"))
    }

    func testParameterCapture() {
        let matcher = RouteMatcher(template: "/api/theme/:id")
        XCTAssertEqual(matcher.match("/api/theme/dark"), ["id": "dark"])
        XCTAssertNil(matcher.match("/api/theme/"))  // 尾斜杠折叠后无段可匹配 :id
        XCTAssertNil(matcher.match("/api/theme"))
    }

    func testMultipleParameters() {
        let matcher = RouteMatcher(template: "/api/:org/:repo")
        XCTAssertEqual(matcher.match("/api/coffic/lumi"), ["org": "coffic", "repo": "lumi"])
    }

    func testSingleWildcard() {
        let matcher = RouteMatcher(template: "/api/*")
        XCTAssertNotNil(matcher.match("/api/anything"))
        XCTAssertNil(matcher.match("/api/a/b"))  // 单段通配不跨段
    }

    func testDoubleWildcardRest() {
        let matcher = RouteMatcher(template: "/static/**")
        XCTAssertEqual(matcher.match("/static"), [:])
        XCTAssertNotNil(matcher.match("/static/a/b/c"))
    }

    func testLeadingTrailingSlashesIgnored() {
        let matcher = RouteMatcher(template: "health")
        XCTAssertEqual(matcher.match("/health/"), [:])
    }

    func testEmptyAndRoot() {
        let matcher = RouteMatcher(template: "/")
        XCTAssertEqual(matcher.match("/"), [:])
        XCTAssertEqual(matcher.match(""), [:])
        XCTAssertNil(matcher.match("/x"))
    }
}
