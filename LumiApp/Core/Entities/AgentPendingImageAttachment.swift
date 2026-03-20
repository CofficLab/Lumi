import Foundation

/// 待发送图片附件
enum AgentPendingImageAttachment: Identifiable, Equatable {
    case image(id: UUID, data: Data, mimeType: String, url: URL)

    var id: UUID {
        switch self {
        case let .image(id, _, _, _): return id
        }
    }

    static func == (lhs: AgentPendingImageAttachment, rhs: AgentPendingImageAttachment) -> Bool {
        switch (lhs, rhs) {
        case let (.image(lid, ldata, lmime, _), .image(rid, rdata, rmime, _)):
            return lid == rid && lmime == rmime && ldata == rdata
        }
    }
}
