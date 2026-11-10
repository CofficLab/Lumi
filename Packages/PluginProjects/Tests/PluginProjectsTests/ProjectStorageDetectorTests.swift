import Foundation
import Testing
@testable import PluginProjects

/// 项目存储类型判定测试。
///
/// 覆盖内置磁盘、外置设备（U 盘/移动硬盘）、网络卷、目录缺失与卷不可达五类分支。
///
/// - Note: 套件标记为 `.serialized`，因为用例会替换全局的存储探测器；
///   Swift Testing 默认并行执行用例，并行替换会互相覆盖。
@MainActor
@Suite("项目存储类型判定", .serialized)
struct ProjectStorageDetectorTests {
    /// 替换存储探测器，测试结束后恢复。
    private func withProbe(
        _ probe: @escaping (String) -> StorageProbeResult,
        _ body: () -> Void
    ) {
        let original = ProjectStorageDetector.probe
        ProjectStorageDetector.probe = probe
        ProjectStorageDetector.invalidateAll()
        defer {
            ProjectStorageDetector.probe = original
            ProjectStorageDetector.invalidateAll()
        }
        body()
    }

    @Test("内置磁盘判定为 internalDisk")
    func internalDiskKind() {
        withProbe({ _ in .traits(VolumeTraits(isLocal: true, isInternal: true)) }) {
            #expect(ProjectStorageDetector.kind(for: "/tmp/project") == .internalDisk)
        }
    }

    @Test("外置设备判定为 externalDisk")
    func externalDiskKind() {
        withProbe({ _ in .traits(VolumeTraits(isLocal: true, isInternal: false)) }) {
            #expect(ProjectStorageDetector.kind(for: "/Volumes/USB/project") == .externalDisk)
        }
    }

    @Test("网络卷判定为 networkVolume")
    func networkVolumeKind() {
        withProbe({ _ in .traits(VolumeTraits(isLocal: false, isInternal: false)) }) {
            #expect(ProjectStorageDetector.kind(for: "/Volumes/NAS/project") == .networkVolume)
        }
    }

    @Test("目录不存在判定为 missingDirectory")
    func missingDirectoryKind() {
        withProbe({ _ in .missingDirectory }) {
            #expect(ProjectStorageDetector.kind(for: "/Volumes/USB/gone") == .missingDirectory)
        }
    }

    @Test("卷属性读不到判定为 unreachableVolume")
    func unreachableVolumeKind() {
        withProbe({ _ in .unreachableVolume }) {
            #expect(ProjectStorageDetector.kind(for: "/Volumes/USB/unmounted") == .unreachableVolume)
        }
    }

    /// 目录缺失与卷不可达是两种不同状态，界面需要区别对待。
    @Test("目录缺失与卷不可达互不混淆")
    func missingDirectoryDiffersFromUnreachableVolume() {
        withProbe({ _ in .missingDirectory }) {
            #expect(ProjectStorageDetector.kind(for: "/tmp/gone") == .missingDirectory)
            #expect(ProjectStorageDetector.kind(for: "/tmp/gone") != .unreachableVolume)
        }
        withProbe({ _ in .unreachableVolume }) {
            #expect(ProjectStorageDetector.kind(for: "/tmp/unmounted") == .unreachableVolume)
            #expect(ProjectStorageDetector.kind(for: "/tmp/unmounted") != .missingDirectory)
        }
    }

    /// 不可用状态需要用特殊图标标记，界面才能一眼看出条目出了问题。
    @Test("不可用状态使用特殊符号并被标记")
    func unavailableStatesUseDistinctSymbols() {
        #expect(ProjectStorageKind.missingDirectory.symbolName == "folder.badge.questionmark")
        #expect(ProjectStorageKind.unreachableVolume.symbolName == "exclamationmark.triangle.fill")
        #expect(ProjectStorageKind.missingDirectory.isUnavailable)
        #expect(ProjectStorageKind.unreachableVolume.isUnavailable)
        #expect(!ProjectStorageKind.internalDisk.isUnavailable)
        #expect(!ProjectStorageKind.externalDisk.isUnavailable)
        #expect(!ProjectStorageKind.networkVolume.isUnavailable)
    }

    @Test("缓存命中后不再重复解析")
    func cachedResultIsReused() {
        var callCount = 0
        withProbe({ _ in
            callCount += 1
            return .traits(VolumeTraits(isLocal: true, isInternal: false))
        }) {
            _ = ProjectStorageDetector.kind(for: "/Volumes/USB/project")
            _ = ProjectStorageDetector.kind(for: "/Volumes/USB/project")
            #expect(callCount == 1)
        }
    }

    @Test("失效缓存后重新解析")
    func invalidatedCacheIsReprobed() {
        var callCount = 0
        withProbe({ _ in
            callCount += 1
            return .traits(VolumeTraits(isLocal: true, isInternal: false))
        }) {
            _ = ProjectStorageDetector.kind(for: "/Volumes/USB/project")
            ProjectStorageDetector.invalidate(path: "/Volumes/USB/project")
            _ = ProjectStorageDetector.kind(for: "/Volumes/USB/project")
            #expect(callCount == 2)
        }
    }

    /// 真实文件系统：临时目录位于本机内置磁盘，应判定为 internalDisk。
    @Test("真实路径判定为本机磁盘")
    func realPathIsInternalDisk() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginProjectsStorage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        ProjectStorageDetector.invalidateAll()
        #expect(ProjectStorageDetector.kind(for: directory.path) == .internalDisk)
    }

    /// 真实文件系统：不存在的路径应判定为 missingDirectory（目录已被删除）。
    @Test("真实不存在路径判定为目录缺失")
    func realMissingPathIsMissingDirectory() {
        let missing = "/Volumes/LumiDoesNotExist-\(UUID().uuidString)/project"
        ProjectStorageDetector.invalidateAll()
        #expect(ProjectStorageDetector.kind(for: missing) == .missingDirectory)
    }

    /// 真实文件系统：目录被删除后，缓存失效能重新探测到「已缺失」。
    @Test("目录删除后刷新能感知到缺失")
    func deletedDirectoryIsDetectedAfterRefresh() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginProjectsDeleted-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        ProjectStorageDetector.invalidateAll()
        #expect(ProjectStorageDetector.kind(for: directory.path) == .internalDisk)

        try FileManager.default.removeItem(at: directory)

        // 缓存未失效时仍返回旧结果；失效后重新探测才能看到目录已消失。
        #expect(ProjectStorageDetector.kind(for: directory.path) == .internalDisk)
        ProjectStorageDetector.invalidateAll()
        #expect(ProjectStorageDetector.kind(for: directory.path) == .missingDirectory)
    }
}
