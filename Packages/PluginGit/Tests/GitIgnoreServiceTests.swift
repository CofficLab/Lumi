import Foundation
import Testing
@testable import GitPlugin

@Suite @MainActor struct GitIgnoreServiceTests {

    @Test func roundTripWriteAndRead() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gitignore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let path = tmp.path

        #expect(!GitIgnoreService.exists(forProjectAt: path))

        let original = """
        # Swift
        .build/
        *.xcuserstate

        # Custom
        !.build/Package.resolved
        """
        try GitIgnoreService.write(original, forProjectAt: path)

        #expect(GitIgnoreService.exists(forProjectAt: path))
        let read = GitIgnoreService.read(forProjectAt: path) ?? ""
        #expect(read == original)
    }

    @Test func parsingRecognizesCommentAndNegationAndDirectory() throws {
        let rules = GitIgnoreService.parse("""
        # comment
        .build/
        *.log
        !keep.log
        """)
        #expect(rules.count == 4)
        #expect(rules[0].kind == .comment)
        #expect(rules[1].kind == .directory)
        #expect(rules[2].kind == .pattern)
        #expect(rules[3].kind == .negation)
    }

    @Test func templatesReturnNonEmptyContent() {
        for name in GitIgnoreService.availableTemplates {
            let body = GitIgnoreService.template(name)
            #expect(body != nil)
            #expect(!(body?.isEmpty ?? true))
        }
    }
}
