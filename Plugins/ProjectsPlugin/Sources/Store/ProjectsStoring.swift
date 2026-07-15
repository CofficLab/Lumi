// MARK: - Store Protocol

@MainActor
public protocol ProjectsStoring: AnyObject {
    var projects: [LumiProjectEntry] { get }
    var currentProject: LumiProjectEntry? { get }

    func select(_ project: LumiProjectEntry)
    @discardableResult
    func add(path: String, select: Bool) throws -> LumiProjectEntry
    func remove(_ project: LumiProjectEntry)
}