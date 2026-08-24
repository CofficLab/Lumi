import Foundation
import Testing
@testable import GitPlugin

/// Regression / crash-reproduction tests for `GitAsyncBridge`.
///
/// ## Crash signature under investigation
///
/// Production crashes (7+ since Jul 9, identical signature):
/// ```
/// queue = 'com.apple.root.user-initiated-qos.cooperative'
///   pthread_self
///   _NSThreadGet0
///   <5 Lumi frames — async continuation resume path>
///   completeTaskWithClosure(...) +1     ← BRK #0xC473 (Swift runtime trap)
/// ```
/// This is a Swift Concurrency runtime invariant trap (EXC_BREAKPOINT/SIGTRAP)
/// surfaced while a `CheckedContinuation` is being resumed on the cooperative
/// thread pool. The faulting instruction (BRK #0xC473) is byte-identical across
/// every crash, confirming one root cause.
///
/// The bridge resumes the continuation from inside a
/// `DispatchQueue.global(qos: .userInitiated).async { }` block (line 21 of
/// GitAsyncBridge.swift). That is the only code in the app that schedules work
/// onto exactly this queue.
///
/// These tests cannot deterministically reproduce the runtime trap (it is
/// timing-dependent and, per Swift Forums, Release-build-only) but they pin
/// down the contract the bridge must uphold: a continuation resumed exactly
/// once, with errors and cancellation handled, across heavy concurrency and
/// re-entrancy through the shared serial queue. If any of these regress, the
/// bridge becomes a much more likely source of the production trap.

private struct Boom: Error {}

@inline(__always)
private func blockSleep(_ seconds: TimeInterval) {
    if seconds <= 0 { return }
    let sem = DispatchSemaphore(value: 0)
    _ = sem.wait(timeout: .now() + seconds)
}

@Suite("GitAsyncBridge crash reproduction")
struct GitAsyncBridgeCrashReproTests {
    private static let sharedQueue =
        DispatchQueue(label: "com.lumi.tests.git-bridge.crash", qos: .userInitiated)

    @Test("many parallel detached tasks through shared serial queue")
    func manyParallelDetachedThroughSharedQueue() async throws {
        let queue = Self.sharedQueue
        let total = await withTaskGroup(of: Int.self) { group in
            for i in 0..<400 {
                group.addTask {
                    await Task.detached { () -> Int in
                        (try? await GitAsyncBridge.perform(on: queue) {
                            blockSleep(0.001)
                            return i
                        }) ?? -1
                    }.value
                }
            }
            var sum = 0
            for await v in group { sum &+= v }
            return sum
        }
        let expected = (0..<400).reduce(0, &+)
        #expect(total == expected)
    }

    @Test("cancelling detached tasks mid-bridge does not trap")
    func cancellingDetachedTasksMidFlight() async throws {
        let queue = Self.sharedQueue
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<300 {
                let t = Task.detached { () -> Int in
                    (try? await GitAsyncBridge.perform(on: queue) {
                        blockSleep(0.01)
                        return 1
                    }) ?? -1
                }
                group.addTask {
                    blockSleep(0.003)
                    t.cancel()
                    _ = await t.value
                }
            }
        }
        #expect(Bool(true))
    }

    @Test("bridge propagates errors thrown from the work body under load")
    func errorPropagationUnderLoad() async throws {
        let queue = Self.sharedQueue
        let failures = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<200 {
                group.addTask {
                    do {
                        _ = try await GitAsyncBridge.perform(on: queue) { throw Boom() }
                        return false
                    } catch is Boom {
                        return true
                    } catch {
                        return false
                    }
                }
            }
            var n = 0
            for await ok in group where ok { n += 1 }
            return n
        }
        #expect(failures == 200)
    }

    @Test("mixed success/error/cancel storm through bridge")
    func mixedStorm() async throws {
        let queue = Self.sharedQueue
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<600 {
                let shouldThrow = i.isMultiple(of: 2)
                let t = Task.detached { () -> Int in
                    if shouldThrow {
                        _ = try? await GitAsyncBridge.perform(on: queue) {
                            blockSleep(0.001)
                            throw Boom()
                        }
                        return 0
                    } else {
                        return (try? await GitAsyncBridge.perform(on: queue) {
                            blockSleep(0.001)
                            return i
                        }) ?? -1
                    }
                }
                group.addTask {
                    if i.isMultiple(of: 5) {
                        blockSleep(0.0005)
                        t.cancel()
                    }
                    _ = await t.value
                }
            }
        }
        #expect(Bool(true))
    }
}
