#if canImport(XCTest)
import XCTest
@testable import PluginIdleTime
@testable import Lumi

final class IdleTimeInferencerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testNoEventsReturnsDefaultFallback() {
        let now = date(2026, 5, 15, 12, 0)
        let snapshot = RestWindowInferencer(calendar: calendar).infer(events: [], now: now)

        XCTAssertEqual(snapshot.restWindow?.source, .defaultFallback)
        XCTAssertEqual(snapshot.restWindow?.startMinuteOfDay, 22 * 60 + 30)
        XCTAssertEqual(snapshot.restWindow?.endMinuteOfDay, 7 * 60 + 30)
        XCTAssertEqual(snapshot.restWindow?.confidence, 0)
    }

    func testDaytimeActivityInfersCrossMidnightRestWindow() throws {
        let now = date(2026, 5, 15, 12, 0)
        let events = activityEvents(
            now: now,
            days: 14,
            hours: [9, 10, 11, 14, 16, 17],
            kind: .editorInput
        )

        let snapshot = RestWindowInferencer(calendar: calendar).infer(events: events, now: now)
        let window = try XCTUnwrap(snapshot.restWindow)

        XCTAssertNotEqual(window.source, .defaultFallback)
        XCTAssertGreaterThanOrEqual(window.confidence, 0.45)
        XCTAssertTrue(window.startMinuteOfDay >= 17 * 60 + 30 || window.startMinuteOfDay <= 3 * 60)
        XCTAssertTrue(window.endMinuteOfDay <= 10 * 60 || window.endMinuteOfDay >= 22 * 60)
    }

    func testNightActivityInfersDaytimeRestWindow() throws {
        let now = date(2026, 5, 15, 12, 0)
        let events = activityEvents(
            now: now,
            days: 14,
            hours: [22, 23, 0, 1, 2, 3],
            kind: .terminalCommandStarted
        )

        let snapshot = RestWindowInferencer(calendar: calendar).infer(events: events, now: now)
        let window = try XCTUnwrap(snapshot.restWindow)

        XCTAssertNotEqual(window.source, .defaultFallback)
        XCTAssertGreaterThanOrEqual(window.confidence, 0.45)
        XCTAssertTrue(window.startMinuteOfDay >= 3 * 60 + 30 && window.startMinuteOfDay <= 16 * 60)
    }

    func testRecentActivityOutweighsOldActivity() throws {
        let now = date(2026, 5, 15, 12, 0)
        let oldNightActivity = activityEvents(
            now: calendar.date(byAdding: .day, value: -24, to: now)!,
            days: 8,
            hours: [22, 23, 0, 1],
            kind: .editorInput
        )
        let recentDayActivity = activityEvents(
            now: now,
            days: 8,
            hours: [9, 10, 11, 14, 15, 16],
            kind: .editorInput
        )

        let snapshot = RestWindowInferencer(calendar: calendar).infer(
            events: oldNightActivity + recentDayActivity,
            now: now
        )
        let window = try XCTUnwrap(snapshot.restWindow)

        XCTAssertTrue(window.contains(date(2026, 5, 15, 23, 0), calendar: calendar))
    }

    private func activityEvents(
        now: Date,
        days: Int,
        hours: [Int],
        kind: IdleActivityKind
    ) -> [IdleActivityEvent] {
        var events: [IdleActivityEvent] = []
        for dayOffset in 0..<days {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            for hour in hours {
                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = hour
                components.minute = 0
                events.append(IdleActivityEvent(timestamp: calendar.date(from: components)!, kind: kind))
            }
        }
        return events
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
#endif
