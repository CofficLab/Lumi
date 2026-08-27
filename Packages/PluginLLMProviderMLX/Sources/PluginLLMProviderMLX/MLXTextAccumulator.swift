import Foundation

final class MLXTextAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    func append(_ value: String) {
        lock.lock()
        text.append(contentsOf: value)
        lock.unlock()
    }

    var value: String {
        lock.lock()
        defer { lock.unlock() }
        return text
    }
}
