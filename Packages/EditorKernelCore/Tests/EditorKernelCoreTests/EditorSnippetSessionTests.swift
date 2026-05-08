import Foundation
import Testing
@testable import EditorKernelCore

@Suite("EditorSnippetSession Tests")
struct EditorSnippetSessionTests {

    @Test
    func placeholderGroupInitialization() {
        let group = EditorSnippetSession.PlaceholderGroup(
            index: 1,
            ranges: [NSRange(location: 10, length: 5), NSRange(location: 20, length: 8)]
        )

        #expect(group.index == 1)
        #expect(group.ranges.count == 2)
        #expect(group.ranges[0] == NSRange(location: 10, length: 5))
        #expect(group.ranges[1] == NSRange(location: 20, length: 8))
    }

    @Test
    func placeholderGroupEquality() {
        let group1 = EditorSnippetSession.PlaceholderGroup(index: 1, ranges: [NSRange(location: 0, length: 5)])
        let group2 = EditorSnippetSession.PlaceholderGroup(index: 1, ranges: [NSRange(location: 0, length: 5)])
        let group3 = EditorSnippetSession.PlaceholderGroup(index: 2, ranges: [NSRange(location: 0, length: 5)])

        #expect(group1 == group2)
        #expect(group1 != group3)
    }

    @Test
    func snippetSessionInitialization() {
        let groups = [
            EditorSnippetSession.PlaceholderGroup(index: 0, ranges: [NSRange(location: 5, length: 3)])
        ]
        let session = EditorSnippetSession(
            groups: groups,
            activeGroupIndex: 0,
            exitSelection: NSRange(location: 50, length: 0)
        )

        #expect(session.groups.count == 1)
        #expect(session.activeGroupIndex == 0)
        #expect(session.exitSelection == NSRange(location: 50, length: 0))
    }

    @Test
    func currentGroupReturnsActiveGroup() {
        let groups = [
            EditorSnippetSession.PlaceholderGroup(index: 0, ranges: [NSRange(location: 5, length: 3)]),
            EditorSnippetSession.PlaceholderGroup(index: 1, ranges: [NSRange(location: 15, length: 7)])
        ]
        let session = EditorSnippetSession(groups: groups, activeGroupIndex: 1, exitSelection: NSRange(location: 0, length: 0))

        #expect(session.currentGroup?.index == 1)
        #expect(session.currentGroup?.ranges.count == 1)
    }

    @Test
    func currentGroupReturnsNilWhenIndexOutOfRange() {
        let groups = [
            EditorSnippetSession.PlaceholderGroup(index: 0, ranges: [NSRange(location: 5, length: 3)])
        ]
        let session = EditorSnippetSession(groups: groups, activeGroupIndex: 5, exitSelection: NSRange(location: 0, length: 0))

        #expect(session.currentGroup == nil)
    }

    @Test
    func currentGroupReturnsNilWhenGroupsEmpty() {
        let session = EditorSnippetSession(groups: [], activeGroupIndex: 0, exitSelection: NSRange(location: 0, length: 0))

        #expect(session.currentGroup == nil)
    }

    @Test
    func snippetSessionEquality() {
        let groups = [EditorSnippetSession.PlaceholderGroup(index: 0, ranges: [NSRange(location: 0, length: 5)])]
        let session1 = EditorSnippetSession(groups: groups, activeGroupIndex: 0, exitSelection: NSRange(location: 10, length: 0))
        let session2 = EditorSnippetSession(groups: groups, activeGroupIndex: 0, exitSelection: NSRange(location: 10, length: 0))

        #expect(session1 == session2)
    }

    @Test
    func snippetSessionInequality() {
        let groups = [EditorSnippetSession.PlaceholderGroup(index: 0, ranges: [NSRange(location: 0, length: 5)])]
        let session1 = EditorSnippetSession(groups: groups, activeGroupIndex: 0, exitSelection: NSRange(location: 10, length: 0))
        let session2 = EditorSnippetSession(groups: groups, activeGroupIndex: 1, exitSelection: NSRange(location: 10, length: 0))

        #expect(session1 != session2)
    }

    @Test
    func multiplePlaceholderGroups() {
        let groups = [
            EditorSnippetSession.PlaceholderGroup(index: 0, ranges: [NSRange(location: 5, length: 3), NSRange(location: 25, length: 3)]),
            EditorSnippetSession.PlaceholderGroup(index: 1, ranges: [NSRange(location: 15, length: 7)]),
            EditorSnippetSession.PlaceholderGroup(index: 2, ranges: [NSRange(location: 35, length: 10)])
        ]
        let session = EditorSnippetSession(groups: groups, activeGroupIndex: 0, exitSelection: NSRange(location: 100, length: 0))

        #expect(session.groups.count == 3)
        #expect(session.groups[0].ranges.count == 2)
        #expect(session.groups[1].ranges.count == 1)
        #expect(session.groups[2].ranges.count == 1)
    }
}