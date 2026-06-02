import XCTest
@testable import XcodeKit

final class XcodePBXProjParserTests: XCTestCase {
    
    // MARK: - parseMembershipGraph(contents:) Tests
    
    func testParseMembershipGraphEmptyContents() throws {
        let result = try XcodePBXProjParser.parseMembershipGraph(contents: "")
        XCTAssertTrue(result.targetRoots.isEmpty)
    }
    
    func testParseMembershipGraphWhitespaceOnly() throws {
        let result = try XcodePBXProjParser.parseMembershipGraph(contents: "   \n  \t  ")
        XCTAssertTrue(result.targetRoots.isEmpty)
    }
    
    // MARK: - TargetRoot Tests
    
    func testTargetRootInitialization() {
        let excludedPaths: Set<String> = ["file1.swift", "file2.swift"]
        let root = XcodePBXProjParser.TargetRoot(
            rootPath: "Sources/App",
            excludedRelativePaths: excludedPaths
        )
        
        XCTAssertEqual(root.rootPath, "Sources/App")
        XCTAssertEqual(root.excludedRelativePaths.count, 2)
        XCTAssertTrue(root.excludedRelativePaths.contains("file1.swift"))
    }
    
    func testTargetRootEmptyExclusions() {
        let root = XcodePBXProjParser.TargetRoot(
            rootPath: "Sources",
            excludedRelativePaths: []
        )
        
        XCTAssertTrue(root.excludedRelativePaths.isEmpty)
    }
    
    // MARK: - MembershipGraph Tests
    
    func testMembershipGraphEmpty() {
        let graph = XcodePBXProjParser.MembershipGraph(targetRoots: [:])
        XCTAssertTrue(graph.targetRoots.isEmpty)
    }
    
    func testMembershipGraphWithTargets() {
        let roots = [
            "App": [
                XcodePBXProjParser.TargetRoot(rootPath: "Sources/App", excludedRelativePaths: []),
            ],
            "Tests": [
                XcodePBXProjParser.TargetRoot(rootPath: "Tests", excludedRelativePaths: []),
            ]
        ]
        let graph = XcodePBXProjParser.MembershipGraph(targetRoots: roots)
        
        XCTAssertEqual(graph.targetRoots.count, 2)
        XCTAssertEqual(graph.targetRoots["App"]?.first?.rootPath, "Sources/App")
        XCTAssertEqual(graph.targetRoots["Tests"]?.first?.rootPath, "Tests")
    }
}
