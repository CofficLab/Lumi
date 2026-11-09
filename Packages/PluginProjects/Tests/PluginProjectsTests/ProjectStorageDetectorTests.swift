import Foundation
import Testing
@testable import PluginProjects

/// 项目存储类型判定测试。
///
/// 覆盖内置磁盘、外置设备（U 盘/移动硬盘）、网络卷与路径不可达四类分支。
///
/// - Note: 套件标记为 `.serialized`，因为用例会替换全局的卷特征解析器；
///   Swift Testing 默认并行执行用例，并行替换会互相覆盖。
@MainActor
@Suite("项目存储类型判定", .serialized)
struct ProjectStorageDetectorTests {
    /// 替换卷特征解析器，测试结束后恢复。
    private func withResolver(
        _ resolver: @escaping (String) -> VolumeTraits?,
        _ body: () -> Void
    ) {
        let original = ProjectStorageDetector.traitsResolver
        ProjectStorageDetector.traitsResolver = resolver
        ProjectStorageDetector.invalidateAll()
        defer {
            ProjectStorageDetector.traitsResolver = original
            ProjectStorageDetector.invalidateAll()
        }
        body()
    }

    @Test("内置磁盘判定为 internalDisk")
    func internalDiskKind() {
        withResolver({ _ in VolumeTraits(isLocal: true, isInternal: true) }) {
            #expect(ProjectStorageDetector.kind(for: "/tmp/project") == .internalDisk)
        }
    }

    @Test("外置设备判定为 externalDisk")
    func externalDiskKind() {
        withResolver({ _ in VolumeTraits(isLocal: true, isInternal: false) }) {
            #expect(ProjectStorageDetector.kind(for: "/Volumes/USB/project") == .externalDisk)
        }
    }

    @Test("网络卷判定为 networkVolume")
    func networkVolumeKind() {
        withResolver({ _ in VolumeTraits(isLocal: false, isInternal: false) }) {
            #expect(ProjectStorageDetector.kind(for: "/Volumes/NAS/project") == .networkVolume)
        }
    }

    @Test("路径不可达判定为 unavailable")
    func unavailableKind() {
        withResolver({ _ in nil }) {
            #expect(ProjectStorageDetector.kind(for: "/Volumes/USB/gone") == .unavailable)
        }
    }

    @Test("缓存命中后不再重复解析")
    func cachedResultIsReused() {
        var callCount = 0
        withResolver({ _ in
            callCount += 1
            return VolumeTraits(isLocal: true, isInternal: false)
        }) {
            _ = ProjectStorageDetector.kind(for: "/Volumes/USB/project")
            _ = ProjectStorageDetector.kind(for: "/Volumes/USB/project")
            #expect(callCount == 1)
        }
    }

    @Test("失效缓存后重新解析")
    func invalidatedCacheIsReprobed() {
        var callCount = 0
        withResolver({ _ in
            callCount += 1
            return VolumeTraits(isLocal: true, isInternal: false)
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

    /// 真实文件系统：不存在的路径应判定为 unavailable（设备已拔出）。
    @Test("真实不存在路径判定为不可达")
    func realMissingPathIsUnavailable() {
        let missing = "/Volumes/LumiDoesNotExist-\(UUID().uuidString)/project"
        ProjectStorageDetector.invalidateAll()
        #expect(ProjectStorageDetector.kind(for: missing) == .unavailable)
    }
}
