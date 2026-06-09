import Foundation

public protocol LumiCurrentProjectPathProviding: Sendable {
    var currentProjectPath: String { get }
}

public protocol LumiCurrentProjectPathStoring: LumiCurrentProjectPathProviding {
    func setCurrentProjectPath(_ path: String)
}

public final class LumiCurrentProjectPathStore: LumiCurrentProjectPathStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var path = ""

    public init() {}

    public var currentProjectPath: String {
        lock.lock()
        defer { lock.unlock() }
        return path
    }

    public func setCurrentProjectPath(_ newValue: String) {
        lock.lock()
        path = newValue
        lock.unlock()
    }
}
