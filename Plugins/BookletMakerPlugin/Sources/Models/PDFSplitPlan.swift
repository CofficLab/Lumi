import Foundation

struct PDFSplitSegment: Identifiable, Equatable, Sendable {
    let index: Int
    let startPage: Int
    let endPage: Int

    var id: Int { index }
    var rangeKey: String { "\(startPage)-\(endPage)" }
    var pageCount: Int { endPage - startPage + 1 }

    func fileName(baseName: String) -> String {
        "\(baseName)-part-\(index).pdf"
    }
}

struct PDFSplitOutput: Identifiable, Equatable, Sendable {
    let segment: PDFSplitSegment
    let fileName: String

    var id: Int { segment.id }
}

enum PDFSplitPlan {
    enum ValidationError: LocalizedError, Equatable {
        case invalidToken(String)
        case cutPointOutOfRange(Int, pageCount: Int)

        var errorDescription: String? {
            switch self {
            case .invalidToken(let token):
                BookletLocalization.string("Invalid page number: %@", token)
            case .cutPointOutOfRange(let page, let pageCount):
                BookletLocalization.string(
                    "Cut points must be between 1 and %lld (found %lld).",
                    Int64(max(pageCount - 1, 0)),
                    Int64(page)
                )
            }
        }
    }

    static func parseCutPoints(_ text: String,
                               pageCount: Int) -> Result<[Int], ValidationError> {
        let normalized = text.replacingOccurrences(of: "，", with: ",")
        let tokens = normalized.split { character in
            character == "," || character.isWhitespace
        }

        var points = Set<Int>()
        for token in tokens {
            guard let page = Int(token) else {
                return .failure(.invalidToken(String(token)))
            }
            guard page >= 1, page < pageCount else {
                return .failure(.cutPointOutOfRange(page, pageCount: pageCount))
            }
            points.insert(page)
        }
        return .success(points.sorted())
    }

    static func segments(pageCount: Int, cutPoints: [Int]) -> [PDFSplitSegment] {
        guard pageCount > 0 else { return [] }
        let validPoints = Array(Set(cutPoints.filter { $0 >= 1 && $0 < pageCount })).sorted()
        var startPage = 1
        var result: [PDFSplitSegment] = []

        for cutPoint in validPoints {
            result.append(PDFSplitSegment(
                index: result.count + 1,
                startPage: startPage,
                endPage: cutPoint
            ))
            startPage = cutPoint + 1
        }
        result.append(PDFSplitSegment(
            index: result.count + 1,
            startPage: startPage,
            endPage: pageCount
        ))
        return result
    }
}
