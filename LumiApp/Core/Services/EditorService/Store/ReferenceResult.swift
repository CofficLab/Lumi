import Foundation

struct ReferenceResult: Identifiable, Equatable {
    var id: String { stableIdentifier }
    let url: URL
    let line: Int
    let column: Int
    let path: String
    let preview: String

    var stableIdentifier: String {
        "\(url.standardizedFileURL.path)#\(line):\(column):\(preview)"
    }
}
