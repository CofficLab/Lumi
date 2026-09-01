import Foundation
import SwiftUI

// MARK: - Content Footer Height

/// 内容区 Footer 的高度约束。
@MainActor
public struct ContentFooterHeight: Equatable, Sendable {
    public let minHeight: CGFloat
    public let idealHeight: CGFloat
    public let maxHeight: CGFloat

    public static let standard = Self(minHeight: 100, idealHeight: 280, maxHeight: .infinity)

    public init(minHeight: CGFloat, idealHeight: CGFloat, maxHeight: CGFloat) {
        let safeMin = minHeight.isFinite ? max(0, minHeight) : 0
        let safeMax: CGFloat
        if maxHeight.isFinite {
            safeMax = max(safeMin, maxHeight)
        } else {
            safeMax = .infinity
        }
        self.minHeight = safeMin
        self.maxHeight = safeMax
        self.idealHeight = Self.clamp(idealHeight, min: safeMin, max: safeMax)
    }

    public func withIdealHeight(_ height: CGFloat) -> Self {
        Self(minHeight: minHeight, idealHeight: height, maxHeight: maxHeight)
    }

    public func clamped(_ height: CGFloat) -> CGFloat {
        Self.clamp(height, min: minHeight, max: maxHeight)
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        let safeValue = value.isFinite ? value : minimum
        return Swift.min(Swift.max(safeValue, minimum), maximum)
    }
}

/// Content Footer 高度偏好的持久化接口。
@MainActor
public protocol ContentFooterHeightStoring: AnyObject {
    func loadHeight(ownerID: String) -> CGFloat?
    func saveHeight(_ height: CGFloat, ownerID: String)
    func removeHeight(ownerID: String)
}

/// 基于 binary plist 的 Content Footer 高度存储。
@MainActor
public final class FileContentFooterHeightStore: ContentFooterHeightStoring {
    private let fileURL: URL
    private var values: [String: Double]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.values = Self.load(from: fileURL)
    }

    public func loadHeight(ownerID: String) -> CGFloat? {
        guard let value = values[ownerID], value.isFinite, value > 0 else { return nil }
        return CGFloat(value)
    }

    public func saveHeight(_ height: CGFloat, ownerID: String) {
        guard !ownerID.isEmpty, height.isFinite, height > 0 else { return }
        values[ownerID] = Double(height)
        persist()
    }

    public func removeHeight(ownerID: String) {
        guard values.removeValue(forKey: ownerID) != nil else { return }
        persist()
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: values,
                format: .binary,
                options: 0
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Keep the in-memory preference effective if the disk is unavailable.
        }
    }

    private static func load(from url: URL) -> [String: Double] {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let values = plist as? [String: Double] else {
            return [:]
        }
        return values
    }
}
