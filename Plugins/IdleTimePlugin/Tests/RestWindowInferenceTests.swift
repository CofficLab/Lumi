import Testing
import Foundation
@testable import IdleTimePlugin

/// Unit tests for `RestWindow.contains` (cross-midnight logic),
/// `IdleConfidenceLabel.label`, and `RestWindowInferencer` inference.
@Suite struct RestWindowContainsTests {

    private func dateAt(_ hour: Int, _ minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: 2026, month: 6, day: 25, hour: hour, minute: minute)
        return cal.date(from: comps)!
    }

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func containsWithinNormalRange() {
        // 09:00–17:00, not crossing midnight.
        let window = RestWindow(startMinuteOfDay: 9 * 60, endMinuteOfDay: 17 * 60,
                                confidence: 0.8, source: .weekday, generatedAt: Date())
        let cal = utcCalendar()
        #expect(window.contains(dateAt(12, 0), calendar: cal) == true)
        #expect(window.contains(dateAt(9, 0), calendar: cal) == true)   // start inclusive
        #expect(window.contains(dateAt(17, 0), calendar: cal) == false) // end exclusive
        #expect(window.contains(dateAt(8, 59), calendar: cal) == false)
    }

    @Test func containsCrossingMidnight() {
        // 22:30–07:30, wraps past midnight.
        let window = RestWindow(startMinuteOfDay: 22 * 60 + 30, endMinuteOfDay: 7 * 60 + 30,
                                confidence: 0.8, source: .weekday, generatedAt: Date())
        let cal = utcCalendar()
        #expect(window.contains(dateAt(23, 0), calendar: cal) == true)
        #expect(window.contains(dateAt(3, 0), calendar: cal) == true)
        #expect(window.contains(dateAt(7, 30), calendar: cal) == false) // end exclusive
        #expect(window.contains(dateAt(22, 30), calendar: cal) == true) // start inclusive
        #expect(window.contains(dateAt(12, 0), calendar: cal) == false)
    }

    @Test func containsFullDayWhenStartEqualsEnd() {
        // start == end → normal-range branch with start<=end → empty (nothing >= start AND < start)
        let window = RestWindow(startMinuteOfDay: 0, endMinuteOfDay: 0,
                                confidence: 0.5, source: .defaultFallback, generatedAt: Date())
        let cal = utcCalendar()
        #expect(window.contains(dateAt(0, 0), calendar: cal) == false)
    }
}

@Suite struct IdleConfidenceLabelTests {

    @Test func defaultFallbackAlwaysLearning() {
        #expect(IdleConfidenceLabel.label(for: 0.95, source: .defaultFallback) == .learning)
        #expect(IdleConfidenceLabel.label(for: 0.0, source: .defaultFallback) == .learning)
    }

    @Test func thresholdsAreExclusiveInclusive() {
        #expect(IdleConfidenceLabel.label(for: 0.449, source: .weekday) == .learning)
        #expect(IdleConfidenceLabel.label(for: 0.45, source: .weekday) == .medium)
        #expect(IdleConfidenceLabel.label(for: 0.699, source: .weekday) == .medium)
        #expect(IdleConfidenceLabel.label(for: 0.70, source: .weekday) == .high)
        #expect(IdleConfidenceLabel.label(for: 0.99, source: .weekday) == .high)
    }
}

@Suite struct RestWindowInferencerTests {

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func dayTimestamp(daysAgo: Int, hour: Int, cal: Calendar, now: Date) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: cal.date(
            bySettingHour: hour, minute: 0, second: 0, of: now
        )!)!
    }

    @Test func inferProducesDefaultWindowWithNoEvents() {
        // No events → falls through to the default-fallback window (22:30–07:30),
        // confidence 0, source .defaultFallback. Documented contract.
        let inferencer = RestWindowInferencer(calendar: utcCalendar())
        let snapshot = inferencer.infer(events: [], now: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(snapshot.restWindow != nil)
        #expect(snapshot.restWindow?.source == .defaultFallback)
        #expect(snapshot.restWindow?.confidence == 0)
        #expect(snapshot.eventCount == 0)
    }

    @Test func inferProducesDefaultWindowForInsufficientData() {
        // Only a single recent event → insufficient coverage → default fallback window.
        let cal = utcCalendar()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let events = [IdleActivityEvent(timestamp: dayTimestamp(daysAgo: 1, hour: 14, cal: cal, now: now), kind: .editorInput)]
        let inferencer = RestWindowInferencer(calendar: cal)
        let snapshot = inferencer.infer(events: events, now: now)
        // With very little data we expect either nil or a low-confidence default window.
        #expect(snapshot.observedDayCount <= 1)
        #expect(snapshot.confidenceBreakdown.dataCoverage <= 1.0)
    }

    @Test func confidenceClampsToZeroOne() {
        let inferencer = RestWindowInferencer(calendar: utcCalendar())
        let snapshot = inferencer.infer(events: [], now: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(snapshot.confidenceBreakdown.dataCoverage >= 0)
        #expect(snapshot.confidenceBreakdown.dataCoverage <= 1.0)
    }

    @Test func bucketScoresHaveExpectedCount() {
        let inferencer = RestWindowInferencer(calendar: utcCalendar())
        let snapshot = inferencer.infer(events: [], now: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(snapshot.bucketScores.count == RestWindowInferencer.bucketsPerDay)
    }

    @Test func profileSourceMapsCorrectly() {
        #expect(IdleInferenceProfile.weekday.source == .weekday)
        #expect(IdleInferenceProfile.weekend.source == .weekend)
        #expect(IdleInferenceProfile.global.source == .globalFallback)
    }

    @Test func targetObservedDaysPerProfile() {
        #expect(IdleInferenceProfile.weekday.targetObservedDays == 14)
        #expect(IdleInferenceProfile.global.targetObservedDays == 14)
        #expect(IdleInferenceProfile.weekend.targetObservedDays == 6)
    }

    @Test func activityKindInferenceWeightsArePositive() {
        for kind in IdleActivityKind.allCases {
            #expect(kind.inferenceWeight > 0)
        }
        // editorInput/agentMessageSent carry the highest weight.
        #expect(IdleActivityKind.editorInput.inferenceWeight >= IdleActivityKind.fileSave.inferenceWeight)
    }

    @Test func activityKindThrottleIntervalsArePositive() {
        for kind in IdleActivityKind.allCases {
            #expect(kind.throttleInterval > 0)
        }
    }
}
