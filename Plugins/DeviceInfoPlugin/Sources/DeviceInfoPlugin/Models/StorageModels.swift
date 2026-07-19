import Foundation

/// Information about a single mounted storage volume.
public struct VolumeInfo: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let totalCapacity: Int64
    public let availableCapacity: Int64
    public let isInternal: Bool
    public let isEjectable: Bool
    public let url: URL

    public init(
        name: String,
        totalCapacity: Int64,
        availableCapacity: Int64,
        isInternal: Bool,
        isEjectable: Bool,
        url: URL
    ) {
        self.name = name
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.isInternal = isInternal
        self.isEjectable = isEjectable
        self.url = url
    }

    /// Used capacity in bytes.
    public var usedCapacity: Int64 {
        max(0, totalCapacity - availableCapacity)
    }

    /// Usage percentage (0–100).
    public var usagePercent: Int {
        guard totalCapacity > 0 else { return 0 }
        return Int(Double(usedCapacity) / Double(totalCapacity) * 100)
    }

    /// Formatted total capacity string (e.g. "500 GB").
    public var totalString: String {
        ByteCountFormatter.string(fromByteCount: totalCapacity, countStyle: .file)
    }

    /// Formatted used capacity string (e.g. "320 GB").
    public var usedString: String {
        ByteCountFormatter.string(fromByteCount: usedCapacity, countStyle: .file)
    }

    /// Formatted available capacity string (e.g. "180 GB").
    public var availableString: String {
        ByteCountFormatter.string(fromByteCount: availableCapacity, countStyle: .file)
    }

    /// Usage fraction (0.0–1.0) for ProgressView.
    public var usageFraction: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(usedCapacity) / Double(totalCapacity)
    }
}
