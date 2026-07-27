import Foundation

struct RAGTrackedProject: Identifiable, Equatable {
    public var id: String { path }
    public let name: String
    public let path: String
}
