import Foundation

public enum BenchmarkKind: String, CaseIterable, Hashable, Identifiable, Sendable {
    case cpu
    case memory
    case disk

    public var id: String { rawValue }
}

public struct BenchmarkMeasurement: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: BenchmarkKind
    public let label: String
    public let value: Double
    public let unit: String
    public let durationMilliseconds: Double
    public let detail: String

    public init(
        kind: BenchmarkKind,
        label: String,
        value: Double,
        unit: String,
        durationMilliseconds: Double,
        detail: String
    ) {
        self.id = "\(kind.rawValue).\(label)"
        self.kind = kind
        self.label = label
        self.value = value
        self.unit = unit
        self.durationMilliseconds = durationMilliseconds
        self.detail = detail
    }
}

public struct BenchmarkReport: Equatable, Sendable {
    public let generatedAt: Date
    public let measurements: [BenchmarkMeasurement]

    public init(generatedAt: Date = Date(), measurements: [BenchmarkMeasurement]) {
        self.generatedAt = generatedAt
        self.measurements = measurements
    }
}

public enum BenchmarkProgress: Equatable, Sendable {
    case preparing
    case cpu
    case memory
    case disk
    case finished

    public var fraction: Double {
        switch self {
        case .preparing: return 0
        case .cpu: return 0.2
        case .memory: return 0.5
        case .disk: return 0.8
        case .finished: return 1
        }
    }
}

public enum BenchmarkError: LocalizedError, Equatable, Sendable {
    case invalidConfiguration(String)
    case io(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message), let .io(message): return message
        }
    }
}
