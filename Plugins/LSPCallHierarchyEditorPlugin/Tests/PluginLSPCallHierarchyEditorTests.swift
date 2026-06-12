import Testing
import EditorService
import LanguageServerProtocol
@testable import LSPCallHierarchyEditorPlugin

@Test func packageLoads() async throws {
    #expect(true)
}

@MainActor
@Test func callHierarchyIgnoresIncomingCallsFromPreviousPrepare() async throws {
    let gate = CallHierarchyTestGate()
    let provider = CallHierarchyProvider(
        requestPrepare: { _, line, _ in
            if line == 2 {
                await gate.markSecondPrepareStarted()
                await gate.waitForSecondPrepareRelease()
                return [CallHierarchyFixture.callHierarchyItem(name: "second")]
            }
            return [CallHierarchyFixture.callHierarchyItem(name: "first")]
        },
        requestIncoming: { item in
            if item.name == "first" {
                await gate.markOldIncomingStarted()
                await gate.waitForOldIncomingRelease()
                return [CallHierarchyIncomingCall(
                    from: CallHierarchyFixture.callHierarchyItem(name: "old caller"),
                    fromRanges: [CallHierarchyFixture.range()]
                )]
            }
            return []
        },
        requestOutgoing: { _ in [] }
    )

    await provider.prepareCallHierarchy(uri: "file:///first.swift", line: 1, character: 0)
    try await waitUntil { provider.rootItem?.name == "first" }
    await gate.waitForOldIncomingStart()

    let secondPrepare = Task { @MainActor in
        await provider.prepareCallHierarchy(uri: "file:///second.swift", line: 2, character: 0)
    }
    await gate.waitForSecondPrepareStart()

    await gate.releaseOldIncoming()
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(provider.incomingCalls.isEmpty)

    await gate.releaseSecondPrepare()
    await secondPrepare.value
    try await waitUntil { provider.rootItem?.name == "second" }
    #expect(provider.incomingCalls.isEmpty)
}

private enum CallHierarchyFixture {
    static func callHierarchyItem(name: String) -> CallHierarchyItem {
        CallHierarchyItem(
            name: name,
            kind: .function,
            tag: nil,
            detail: nil,
            uri: "file:///\(name).swift",
            range: range(),
            selectionRange: range(),
            data: nil
        )
    }

    static func range() -> LSPRange {
        LSPRange(
            start: Position(line: 0, character: 0),
            end: Position(line: 0, character: 1)
        )
    }
}

private actor CallHierarchyTestGate {
    private var oldIncomingStarted = false
    private var oldIncomingStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseOldIncomingWaiters: [CheckedContinuation<Void, Never>] = []
    private var shouldReleaseOldIncoming = false

    private var secondPrepareStarted = false
    private var secondPrepareStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseSecondPrepareWaiters: [CheckedContinuation<Void, Never>] = []
    private var shouldReleaseSecondPrepare = false

    func markOldIncomingStarted() {
        oldIncomingStarted = true
        oldIncomingStartWaiters.forEach { $0.resume() }
        oldIncomingStartWaiters.removeAll()
    }

    func waitForOldIncomingStart() async {
        if oldIncomingStarted { return }
        await withCheckedContinuation { continuation in
            oldIncomingStartWaiters.append(continuation)
        }
    }

    func releaseOldIncoming() {
        shouldReleaseOldIncoming = true
        releaseOldIncomingWaiters.forEach { $0.resume() }
        releaseOldIncomingWaiters.removeAll()
    }

    func waitForOldIncomingRelease() async {
        if shouldReleaseOldIncoming { return }
        await withCheckedContinuation { continuation in
            releaseOldIncomingWaiters.append(continuation)
        }
    }

    func markSecondPrepareStarted() {
        secondPrepareStarted = true
        secondPrepareStartWaiters.forEach { $0.resume() }
        secondPrepareStartWaiters.removeAll()
    }

    func waitForSecondPrepareStart() async {
        if secondPrepareStarted { return }
        await withCheckedContinuation { continuation in
            secondPrepareStartWaiters.append(continuation)
        }
    }

    func releaseSecondPrepare() {
        shouldReleaseSecondPrepare = true
        releaseSecondPrepareWaiters.forEach { $0.resume() }
        releaseSecondPrepareWaiters.removeAll()
    }

    func waitForSecondPrepareRelease() async {
        if shouldReleaseSecondPrepare { return }
        await withCheckedContinuation { continuation in
            releaseSecondPrepareWaiters.append(continuation)
        }
    }
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now + .nanoseconds(Int(timeoutNanoseconds))
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    Issue.record("Timed out waiting for condition")
}
