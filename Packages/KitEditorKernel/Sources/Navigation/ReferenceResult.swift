import Foundation

public struct ReferenceResult: Identifiable, Equatable {
    public let url: URL
    public let line: Int
    public let column: Int
    public let path: String
    public let preview: String

    public var id: String { stableIdentifier }

    public var stableIdentifier: String {
        "\(url.standardizedFileURL.path)#\(line):\(column):\(preview)"
    }

    public init(
        url: URL,
        line: Int,
        column: Int,
        path: String,
        preview: String
    ) {
        self.url = url
        self.line = line
        self.column = column
        self.path = path
        self.preview = preview
    }
}
