import Foundation
import Testing
@testable import XcodeKit

@Test func resolutionProgressPreservesStartedAtWithinSamePhase() {
    let startedAt = Date(timeIntervalSinceReferenceDate: 100)
    let initial = BuildContextResolutionProgress(
        phase: .parsingProjectMembership,
        detail: "Lumi.xcodeproj",
        startedAt: startedAt
    )
    let updated = BuildContextResolutionProgress(
        updating: initial,
        with: .init(phase: .parsingProjectMembership, currentItem: "AppBootstrap.swift")
    )
    #expect(updated.startedAt == startedAt)
    #expect(updated.currentItem == "AppBootstrap.swift")
    #expect(updated.detail == "Lumi.xcodeproj")
}

@Test func resolutionProgressResetsStartedAtWhenPhaseChanges() {
    let initial = BuildContextResolutionProgress(
        phase: .discoveringSchemes,
        startedAt: Date(timeIntervalSinceReferenceDate: 50)
    )
    let updated = BuildContextResolutionProgress(
        updating: initial,
        with: .init(phase: .runningXcodebuildList, detail: "Lumi.xcodeproj")
    )
    #expect(updated.phase == .runningXcodebuildList)
    #expect(updated.startedAt > initial.startedAt)
}

@Test func formattedElapsedUsesMinutesWhenNeeded() {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let now = Date(timeIntervalSinceReferenceDate: 83)
    #expect(BuildContextResolutionProgress.formattedElapsed(since: start, now: now) == "1:23")
}

@Test func formattedElapsedUsesSecondsForShortDurations() {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let now = Date(timeIntervalSinceReferenceDate: 9)
    #expect(BuildContextResolutionProgress.formattedElapsed(since: start, now: now) == "9s")
}

@Test func showsElapsedTimeAfterOneSecondForLongPhases() {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let progress = BuildContextResolutionProgress(phase: .runningXcodebuildList, startedAt: start)
    #expect(!progress.showsElapsedTime(at: Date(timeIntervalSinceReferenceDate: 0.5)))
    #expect(progress.showsElapsedTime(at: Date(timeIntervalSinceReferenceDate: 2)))
}

@Test func throttledScanProgressReporterLimitsCallbacks() {
    final class Counter: @unchecked Sendable {
        var value = 0
    }
    let counter = Counter()
    let reporter = ThrottledScanProgressReporter(minimumInterval: 1)
    reporter.report("/a.swift") { _ in counter.value += 1 }
    reporter.report("/b.swift") { _ in counter.value += 1 }
    #expect(counter.value == 1)
}
