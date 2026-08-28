import Foundation

struct HTTPExchangeDailyCountPoint: Equatable, Identifiable, Sendable {
    let day: Date
    let count: Int

    var id: Date { day }
}

struct HTTPExchangeDailyCountSeries: Equatable, Sendable {
    let points: [HTTPExchangeDailyCountPoint]

    var totalCount: Int {
        points.reduce(0) { $0 + $1.count }
    }

    var peakCount: Int {
        points.map(\.count).max() ?? 0
    }

    static func build(
        records: [HTTPExchangeRecord],
        calendar: Calendar = .current,
        days: Int = 14,
        endingAt date: Date = Date()
    ) -> HTTPExchangeDailyCountSeries {
        guard days > 0 else { return HTTPExchangeDailyCountSeries(points: []) }

        let today = calendar.startOfDay(for: date)
        let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        var counts: [Date: Int] = Dictionary(uniqueKeysWithValues: (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            return (day, 0)
        })

        for record in records {
            let day = calendar.startOfDay(for: record.startedAt)
            guard day >= firstDay, day <= today else { continue }
            counts[day, default: 0] += 1
        }

        let points = (0..<days).compactMap { offset -> HTTPExchangeDailyCountPoint? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            return HTTPExchangeDailyCountPoint(day: day, count: counts[day, default: 0])
        }
        return HTTPExchangeDailyCountSeries(points: points)
    }
}
