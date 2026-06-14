import Foundation


extension StyledRangeContainer {
    func exportHighlightRanges(providerId: ProviderID) -> [HighlightRange] {
        guard let store = _storage[providerId]?.store else { return [] }
        let length = store.length
        guard length > 0 else { return [] }

        var highlights: [HighlightRange] = []
        var offset = 0
        for run in store.runs(in: 0..<length) {
            defer { offset += run.length }
            guard let capture = run.value?.capture else { continue }
            highlights.append(
                HighlightRange(
                    range: NSRange(location: offset, length: run.length),
                    capture: capture,
                    modifiers: run.value?.modifiers ?? []
                )
            )
        }
        return highlights
    }
}
