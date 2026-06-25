import Testing
import Foundation
@testable import CaffeinatePlugin

/// Unit tests for the pure value-type logic in CaffeinatePlugin: duration
/// conversions, the common-durations preset list, and sleep-mode labels.
@MainActor
@Suite struct CaffeinateDurationOptionTests {

    @Test func indefiniteTimeIntervalIsZero() {
        #expect(CaffeinateManager.DurationOption.indefinite.timeInterval == 0)
    }

    @Test func minutesConvertToSeconds() {
        #expect(CaffeinateManager.DurationOption.minutes(10).timeInterval == 600)
        #expect(CaffeinateManager.DurationOption.minutes(30).timeInterval == 1800)
        #expect(CaffeinateManager.DurationOption.minutes(1).timeInterval == 60)
    }

    @Test func hoursConvertToSeconds() {
        #expect(CaffeinateManager.DurationOption.hours(1).timeInterval == 3600)
        #expect(CaffeinateManager.DurationOption.hours(2).timeInterval == 7200)
    }

    @Test func displayNameIsNonEmpty() {
        for option in CaffeinateManager.commonDurations {
            #expect(!option.displayName.isEmpty)
        }
        #expect(!CaffeinateManager.DurationOption.indefinite.displayName.isEmpty)
    }

    @Test func commonDurationsIsStable() {
        // Lock the preset list so UI/menu ordering doesn't drift unnoticed.
        #expect(CaffeinateManager.commonDurations.count >= 5)
        #expect(CaffeinateManager.commonDurations.first == .indefinite)
        #expect(CaffeinateManager.commonDurations.contains(.minutes(10)))
        #expect(CaffeinateManager.commonDurations.contains(.hours(1)))
    }

    @Test func durationOptionEquatable() {
        #expect(CaffeinateManager.DurationOption.minutes(10) == .minutes(10))
        #expect(CaffeinateManager.DurationOption.minutes(10) != .minutes(30))
        #expect(CaffeinateManager.DurationOption.hours(1) != .minutes(60))
    }
}

@MainActor
@Suite struct CaffeinateSleepModeTests {

    @Test func allCasesCovered() {
        #expect(CaffeinateManager.SleepMode.allCases.count == 2)
    }

    @Test func displayNameIsNonEmpty() {
        for mode in CaffeinateManager.SleepMode.allCases {
            #expect(!mode.displayName.isEmpty)
        }
    }

    @Test func displayNameDistinguishesModes() {
        let system = CaffeinateManager.SleepMode.systemOnly.displayName
        let both = CaffeinateManager.SleepMode.systemAndDisplay.displayName
        #expect(system != both)
    }
}
