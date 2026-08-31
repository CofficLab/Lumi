import Foundation

/// The status bucket used by the HTTP log list. It is deliberately independent
/// from the settings view so the store can apply the same query everywhere.
enum HTTPExchangeStatusFilter: Sendable {
    case all
    case normal
    case abnormal
}

/// Lightweight data used by the HTTP log list. Body data is intentionally not
/// part of this type: a list query must never materialize request or response
/// payloads for records that are not being inspected.
struct HTTPExchangeListSnapshot: Sendable, Identifiable {
    let id: UUID
    let method: String
    let url: String
    let startedAt: Date
    let responseStatusCode: Int?
    let errorDescription: String?

    init(record: HTTPExchangeRecord) {
        id = record.id
        method = record.requestMethod
        url = record.requestURL
        startedAt = record.startedAt
        responseStatusCode = record.responseStatusCode
        errorDescription = record.errorDescription
    }
}

struct HTTPExchangeListPage: Sendable {
    let records: [HTTPExchangeListSnapshot]
    let nextCursor: Date?
    let hasMore: Bool
}
