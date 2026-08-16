import Foundation
public struct IdleSnapshot: Sendable, Equatable { public let lastActivityAt: Date?; public init(lastActivityAt: Date? = nil) { self.lastActivityAt = lastActivityAt } }
public protocol IdleTimeProviding: AnyObject, Sendable { func record(at date: Date) async; func snapshot(at date: Date) async -> IdleSnapshot }
public final actor DefaultIdleTimeProviding: IdleTimeProviding { private var lastActivityAt: Date?; public init() {}; public func record(at date: Date = Date()) async { lastActivityAt = date }; public func snapshot(at date: Date = Date()) async -> IdleSnapshot { IdleSnapshot(lastActivityAt: lastActivityAt) } }
