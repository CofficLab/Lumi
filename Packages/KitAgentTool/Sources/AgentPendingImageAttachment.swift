import Foundation

public enum AgentPendingImageAttachment: Identifiable, Equatable, Sendable {
    case image(id: UUID, data: Data, mimeType: String, url: URL)

    public var id: UUID {
        switch self {
        case let .image(id, _, _, _): return id
        }
    }

    public static func == (lhs: AgentPendingImageAttachment, rhs: AgentPendingImageAttachment) -> Bool {
        switch (lhs, rhs) {
        case let (.image(lid, ldata, lmime, _), .image(rid, rdata, rmime, _)):
            return lid == rid && lmime == rmime && ldata == rdata
        }
    }
}
