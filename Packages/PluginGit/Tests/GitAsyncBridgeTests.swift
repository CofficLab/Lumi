import Foundation
import Testing
@testable import GitPlugin

private struct TestGitError: Error {}

@Test func continuationGuardCompletesOnlyOnce() async throws {
    let value: String = try await withCheckedThrowingContinuation { continuation in
        let guardBox = ContinuationGuard(continuation)
        guardBox.complete(with: .success("first"))
        guardBox.complete(with: .failure(TestGitError()))
        guardBox.complete(with: .success("second"))
    }

    #expect(value == "first")
}

@Test func gitAsyncBridgeHandlesManyConcurrentCalls() async throws {
    let queue = DispatchQueue(label: "com.lumi.tests.git-async-bridge")

    let sum = try await withThrowingTaskGroup(of: Int.self) { group in
        for index in 0..<100 {
            group.addTask {
                try await GitAsyncBridge.perform(on: queue) {
                    index
                }
            }
        }

        var total = 0
        for try await value in group {
            total += value
        }
        return total
    }

    #expect(sum == (0..<100).reduce(0, +))
}

@Test func gitAsyncBridgePropagatesWorkQueueErrors() async throws {
    let queue = DispatchQueue(label: "com.lumi.tests.git-async-bridge.errors")

    await #expect(throws: TestGitError.self) {
        try await GitAsyncBridge.perform(on: queue) {
            throw TestGitError()
        }
    }
}

@Test func gitAsyncBridgeSupportsNestedAsyncCallsThroughSharedQueue() async throws {
    let queue = DispatchQueue(label: "com.lumi.tests.git-async-bridge.nested")

    let total = try await withThrowingTaskGroup(of: Int.self) { group in
        for index in 0..<30 {
            group.addTask {
                let outer = try await GitAsyncBridge.perform(on: queue) { index }
                return try await GitAsyncBridge.perform(on: queue) { outer + 1 }
            }
        }

        var sum = 0
        for try await value in group {
            sum += value
        }
        return sum
    }

    #expect(total == (1...30).reduce(0, +))
}
