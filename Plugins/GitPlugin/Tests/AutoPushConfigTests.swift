import Foundation
import Testing
@testable import GitPlugin

@Suite @MainActor struct AutoPushConfigTests {

    @Test func defaultConfigHasReasonableValues() {
        let cfg = AutoPushConfig.default
        #expect(cfg.enabled == false)
        #expect(cfg.intervalSeconds == 60)
        #expect(cfg.minUnpushedCommits == 0)
        #expect(cfg.remote == "origin")
        #expect(cfg.requireCleanWorkingTree == true)
    }

    @Test func configIsCodable() throws {
        let cfg = AutoPushConfig(
            enabled: true,
            intervalSeconds: 120,
            minUnpushedCommits: 3,
            remote: "upstream",
            requireCleanWorkingTree: false
        )
        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(AutoPushConfig.self, from: data)
        #expect(decoded == cfg)
    }
}

@Suite @MainActor struct GitConflictModelTests {
    @Test func conflictPathsDeduplicate() {
        let a = GitConflictService.Conflict(path: "x")
        let b = GitConflictService.Conflict(path: "x")
        #expect(a == b)
        #expect(a.id == b.id)
    }
}
