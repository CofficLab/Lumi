import Foundation

struct RestWindowInferencer: Sendable {
    static let bucketsPerDay = 48
    static let bucketMinutes = 30

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func infer(events: [IdleActivityEvent], now: Date = Date()) -> IdleInferenceSnapshot {
        let recentEvents = events.filter {
            guard let daysAgo = calendar.dateComponents([.day], from: $0.timestamp, to: now).day else {
                return false
            }
            return daysAgo >= 0 && daysAgo <= 35
        }

        let isWeekendNow = calendar.isDateInWeekend(now)
        let preferredProfile: IdleInferenceProfile = isWeekendNow ? .weekend : .weekday

        let profileEvents = filteredEvents(recentEvents, for: preferredProfile)
        let profileSnapshot = infer(events: profileEvents, allEvents: recentEvents, now: now, profile: preferredProfile)

        if let window = profileSnapshot.restWindow, window.confidence >= 0.45 {
            return profileSnapshot
        }

        let globalSnapshot = infer(events: recentEvents, allEvents: recentEvents, now: now, profile: .global)
        if let window = globalSnapshot.restWindow, window.confidence >= 0.45 {
            return globalSnapshot
        }

        return defaultSnapshot(from: recentEvents, now: now, bucketScores: globalSnapshot.bucketScores)
    }

    func infer(
        events: [IdleActivityEvent],
        allEvents: [IdleActivityEvent],
        now: Date,
        profile: IdleInferenceProfile
    ) -> IdleInferenceSnapshot {
        let bucketScores = scores(for: events, now: now)
        let observedDayCount = observedDays(in: events)
        let eventCount = events.count
        let lastActivityAt = allEvents.map(\.timestamp).max()

        guard eventCount > 0, observedDayCount > 0 else {
            return IdleInferenceSnapshot(
                restWindow: nil,
                observedDayCount: observedDayCount,
                eventCount: eventCount,
                lastActivityAt: lastActivityAt,
                bucketScores: bucketScores,
                confidenceBreakdown: .zero
            )
        }

        let candidate = bestWindow(from: bucketScores)
        let dataCoverage = min(1.0, Double(observedDayCount) / Double(profile.targetObservedDays))
        let contrastScore = contrastScore(avgInside: candidate.avgInside, avgOutside: candidate.avgOutside)
        let stability = stabilityScore(events: events, aggregateStart: candidate.startBucket, now: now)
        let confidence = clamp01(dataCoverage * 0.35 + contrastScore * 0.45 + stability * 0.20)

        let window = RestWindow(
            startMinuteOfDay: candidate.startBucket * Self.bucketMinutes,
            endMinuteOfDay: ((candidate.startBucket + candidate.length) % Self.bucketsPerDay) * Self.bucketMinutes,
            confidence: confidence,
            source: profile.source,
            generatedAt: now
        )

        return IdleInferenceSnapshot(
            restWindow: window,
            observedDayCount: observedDayCount,
            eventCount: eventCount,
            lastActivityAt: lastActivityAt,
            bucketScores: bucketScores,
            confidenceBreakdown: ConfidenceBreakdown(
                dataCoverage: dataCoverage,
                contrast: contrastScore,
                stability: stability
            )
        )
    }

    private func filteredEvents(_ events: [IdleActivityEvent], for profile: IdleInferenceProfile) -> [IdleActivityEvent] {
        switch profile {
        case .global:
            return events
        case .weekday:
            return events.filter { !calendar.isDateInWeekend($0.timestamp) }
        case .weekend:
            return events.filter { calendar.isDateInWeekend($0.timestamp) }
        }
    }

    private func scores(for events: [IdleActivityEvent], now: Date) -> [Double] {
        var scores = Array(repeating: 0.0, count: Self.bucketsPerDay)
        for event in events {
            let components = calendar.dateComponents([.hour, .minute], from: event.timestamp)
            let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            let bucket = min(Self.bucketsPerDay - 1, max(0, minuteOfDay / Self.bucketMinutes))
            let daysAgo = Double(max(0, calendar.dateComponents([.day], from: event.timestamp, to: now).day ?? 0))
            let recencyWeight = Foundation.exp(-daysAgo / 14.0)
            scores[bucket] += event.kind.inferenceWeight * recencyWeight
        }
        return scores
    }

    private func observedDays(in events: [IdleActivityEvent]) -> Int {
        Set(events.map { calendar.startOfDay(for: $0.timestamp) }).count
    }

    private struct WindowCandidate {
        let startBucket: Int
        let length: Int
        let avgInside: Double
        let avgOutside: Double
        let cost: Double
    }

    private func bestWindow(from scores: [Double]) -> WindowCandidate {
        let minBuckets = 12
        let maxBuckets = 20
        let preferredBuckets = 16
        let total = scores.reduce(0, +)
        var best: WindowCandidate?

        for start in 0..<Self.bucketsPerDay {
            for length in minBuckets...maxBuckets {
                let inside = sumCircular(scores, start: start, length: length)
                let outside = total - inside
                let avgInside = inside / Double(length)
                let outsideLength = Self.bucketsPerDay - length
                let avgOutside = outsideLength > 0 ? outside / Double(outsideLength) : 0
                let contrast = max(0, avgOutside - avgInside)
                let durationPenalty = Double(abs(length - preferredBuckets)) * 0.05
                let cost = avgInside - contrast * 0.7 + durationPenalty
                let candidate = WindowCandidate(
                    startBucket: start,
                    length: length,
                    avgInside: avgInside,
                    avgOutside: avgOutside,
                    cost: cost
                )

                if best == nil || candidate.cost < best!.cost {
                    best = candidate
                }
            }
        }

        return best ?? WindowCandidate(startBucket: 45, length: 18, avgInside: 0, avgOutside: 0, cost: 0)
    }

    private func sumCircular(_ scores: [Double], start: Int, length: Int) -> Double {
        guard !scores.isEmpty else { return 0 }
        var sum = 0.0
        for offset in 0..<length {
            sum += scores[(start + offset) % scores.count]
        }
        return sum
    }

    private func contrastScore(avgInside: Double, avgOutside: Double) -> Double {
        guard avgOutside > 0 else { return 0 }
        return clamp01((avgOutside - avgInside) / avgOutside)
    }

    private func stabilityScore(events: [IdleActivityEvent], aggregateStart: Int, now: Date) -> Double {
        let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.timestamp) }
        let starts = grouped.values.compactMap { dayEvents -> Int? in
            guard dayEvents.count >= 2 else { return nil }
            return bestWindow(from: scores(for: dayEvents, now: now)).startBucket
        }
        guard !starts.isEmpty else { return 0.25 }

        let averageDistance = starts
            .map { circularDistance($0, aggregateStart, modulus: Self.bucketsPerDay) }
            .reduce(0, +) / starts.count
        return clamp01(1.0 - Double(averageDistance) / 12.0)
    }

    private func circularDistance(_ lhs: Int, _ rhs: Int, modulus: Int) -> Int {
        let direct = abs(lhs - rhs)
        return min(direct, modulus - direct)
    }

    private func defaultSnapshot(
        from events: [IdleActivityEvent],
        now: Date,
        bucketScores: [Double]
    ) -> IdleInferenceSnapshot {
        let window = RestWindow(
            startMinuteOfDay: 22 * 60 + 30,
            endMinuteOfDay: 7 * 60 + 30,
            confidence: 0,
            source: .defaultFallback,
            generatedAt: now
        )

        return IdleInferenceSnapshot(
            restWindow: window,
            observedDayCount: observedDays(in: events),
            eventCount: events.count,
            lastActivityAt: events.map(\.timestamp).max(),
            bucketScores: bucketScores,
            confidenceBreakdown: .zero
        )
    }

    private func clamp01(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
