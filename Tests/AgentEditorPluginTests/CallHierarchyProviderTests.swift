#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class CallHierarchyProviderTests: XCTestCase {
    func testPrepareCallHierarchyClearsStateWhenNoRootItemReturned() async {
        let provider = CallHierarchyProvider(
            requestPrepare: { _, _, _ in [] },
            requestIncoming: { _ in
                XCTFail("incoming should not be requested when prepare returns no items")
                return []
            },
            requestOutgoing: { _ in
                XCTFail("outgoing should not be requested when prepare returns no items")
                return []
            }
        )

        provider.rootItem = EditorCallHierarchyItem(item: makeItem(name: "OldRoot"))
        provider.incomingCalls = [EditorCallHierarchyCall(item: makeItem(name: "Caller"), fromRanges: [])]
        provider.outgoingCalls = [EditorCallHierarchyCall(item: makeItem(name: "Callee"), fromRanges: [])]

        await provider.prepareCallHierarchy(uri: "file:///tmp/demo.swift", line: 0, character: 0)
        try? await Task.sleep(for: .milliseconds(10))

        XCTAssertNil(provider.rootItem)
        XCTAssertTrue(provider.incomingCalls.isEmpty)
        XCTAssertTrue(provider.outgoingCalls.isEmpty)
        XCTAssertFalse(provider.isLoading)
    }

    func testPrepareCallHierarchyMapsIncomingAndOutgoingCalls() async {
        let root = makeItem(name: "EditorPlugin")
        let incoming = CallHierarchyIncomingCall(
            from: makeItem(name: "Caller"),
            fromRanges: [.init(start: .init(line: 1, character: 2), end: .init(line: 1, character: 8))]
        )
        let outgoing = CallHierarchyOutgoingCall(
            to: makeItem(name: "Callee"),
            fromRanges: [.init(start: .init(line: 3, character: 1), end: .init(line: 3, character: 6))]
        )

        let provider = CallHierarchyProvider(
            requestPrepare: { _, _, _ in [root] },
            requestIncoming: { item in
                XCTAssertEqual(item.name, "EditorPlugin")
                return [incoming]
            },
            requestOutgoing: { item in
                XCTAssertEqual(item.name, "EditorPlugin")
                return [outgoing]
            }
        )

        await provider.prepareCallHierarchy(uri: root.uri, line: 0, character: 0)
        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(provider.rootItem?.name, "EditorPlugin")
        XCTAssertEqual(provider.incomingCalls.map(\.item.name), ["Caller"])
        XCTAssertEqual(provider.outgoingCalls.map(\.item.name), ["Callee"])
        XCTAssertFalse(provider.isLoading)
    }

    private func makeItem(name: String) -> LanguageServerProtocol.CallHierarchyItem {
        LanguageServerProtocol.CallHierarchyItem(
            name: name,
            kind: .method,
            tag: nil,
            detail: nil,
            uri: "file:///tmp/\(name).swift",
            range: .init(start: .init(line: 0, character: 0), end: .init(line: 0, character: 4)),
            selectionRange: .init(start: .init(line: 0, character: 0), end: .init(line: 0, character: 4)),
            data: nil
        )
    }
}
#endif
