import Foundation

struct ConversationDailyCountPoint: Equatable, Identifiable, Sendable {
    let day: Date
    let count: Int

    var id: Date { day }
}

struct ConversationDailyCountSeries: Equatable, Sendable {
    let points: [ConversationDailyCountPoint]

    var peakCount: Int {
        points.map(\.count).max() ?? 0
    }
}
