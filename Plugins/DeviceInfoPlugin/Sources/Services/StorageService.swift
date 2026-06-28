import Combine
import Foundation
import os
import SuperLogKit

/// Storage volume monitoring service.
///
/// Scans all mounted volumes via `FileManager.default.mountedVolumeURLs`,
/// separates internal (system) and external volumes, and publishes updates.
@MainActor
public final class StorageService: ObservableObject, SuperLog {
    public static let shared = StorageService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.storage")
    nonisolated public static let emoji = "💾"

    // MARK: - Published Properties

    /// Internal (system) root volume info.
    @Published public private(set) var rootVolume: VolumeInfo?

    /// External volumes (up to 3).
    @Published public private(set) var externalVolumes: [VolumeInfo] = []

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var subscribersCount = 0

    package init() {}

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            Self.logger.info("\(Self.t)\(Self.emoji) 开始存储卷监控")
            scanVolumes()

            monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.scanVolumes()
                }
            }
        }
    }

    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            Self.logger.info("\(Self.t)\(Self.emoji) 停止存储卷监控")
            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }
    }

    // MARK: - Volume Scanning

    private func scanVolumes() {
        let result = Self.detectVolumes()
        self.rootVolume = result.rootVolume
        self.externalVolumes = result.externalVolumes
    }

    private nonisolated static func detectVolumes() -> (rootVolume: VolumeInfo?, externalVolumes: [VolumeInfo]) {
        let keys: [URLResourceKey] = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeNameKey,
            .volumeIsInternalKey,
            .volumeIsEjectableKey,
        ]

        guard let volumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: []
        ) else {
            return (nil, [])
        }

        var rootVolume: VolumeInfo?
        var externalVolumes: [VolumeInfo] = []

        for url in volumeURLs {
            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: Set(keys))
            } catch {
                continue
            }

            guard let totalCapacity = values.volumeTotalCapacity,
                  let availableCapacity = values.volumeAvailableCapacity,
                  let name = values.volumeName,
                  !name.isEmpty,
                  totalCapacity > 0 else {
                continue
            }

            let isInternal = values.volumeIsInternal ?? true
            let isEjectable = values.volumeIsEjectable ?? false

            let info = VolumeInfo(
                name: name,
                totalCapacity: Int64(totalCapacity),
                availableCapacity: Int64(availableCapacity),
                isInternal: isInternal,
                isEjectable: isEjectable,
                url: url
            )

            if url.path == "/" {
                rootVolume = info
            } else if !isInternal {
                externalVolumes.append(info)
            }
        }

        // Limit to 3 external volumes
        return (rootVolume, Array(externalVolumes.prefix(3)))
    }
}
