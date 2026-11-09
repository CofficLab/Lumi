import Foundation

/// 存储卷特征：区分本机磁盘、外置设备与网络卷。
struct VolumeTraits: Equatable, Sendable {
    /// 是否为本地卷（网络卷为 false）。
    let isLocal: Bool
    /// 是否为内置卷（外置设备为 false）。
    let isInternal: Bool
}

/// 探测项目所在存储卷的类型（内置磁盘 / 外置设备 / 网络卷 / 不可达）。
///
/// ## 为什么单独一层
///
/// 工具栏胶囊与项目列表需要区分「本地磁盘」和「U 盘、移动硬盘」等外置设备，
/// 但判定依赖文件系统状态，属于易变信息，不适合塞进持久化的 `ProjectEntry`。
/// 因此这里按需探测 + 内存缓存，避免每次 SwiftUI 重绘都打一次文件系统。
///
/// ## 判定依据
///
/// - `volumeIsInternal == false`：该路径位于外置卷（U 盘、移动硬盘、外置硬盘盒）。
/// - `volumeIsLocal == false`：该路径位于网络卷（NAS、SMB/NFS 挂载）。
/// - 路径不可达：设备已拔出或目录被删除。
@MainActor
enum ProjectStorageDetector {
    /// 探测结果缓存。键为项目路径，值为判定结果。
    private static var cache: [String: ProjectStorageKind] = [:]

    /// 卷特征解析器。默认读取文件系统资源值；测试可替换以覆盖各类分支。
    nonisolated(unsafe) static var traitsResolver: (String) -> VolumeTraits? = { path in
        let url = URL(fileURLWithPath: path)

        // 路径不存在：设备可能已拔出，或目录被删除。
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let keys: Set<URLResourceKey> = [.volumeIsLocalKey, .volumeIsInternalKey]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            return nil
        }

        return VolumeTraits(
            isLocal: values.volumeIsLocal ?? true,
            isInternal: values.volumeIsInternal ?? true
        )
    }

    /// 探测指定路径的存储类型。
    static func kind(for path: String) -> ProjectStorageKind {
        if let cached = cache[path] {
            return cached
        }
        let result = detect(path: path)
        cache[path] = result
        return result
    }

    /// 清除指定路径的缓存。路径失效或设备挂载状态变化时调用。
    static func invalidate(path: String) {
        cache.removeValue(forKey: path)
    }

    /// 清除全部缓存。
    static func invalidateAll() {
        cache.removeAll()
    }

    /// 实际执行探测。
    private static func detect(path: String) -> ProjectStorageKind {
        guard let traits = traitsResolver(path) else {
            return .unavailable
        }

        // 网络卷优先判定：网络卷通常也不是 internal，但「网络」比「外置」更精确。
        if !traits.isLocal {
            return .networkVolume
        }
        if !traits.isInternal {
            return .externalDisk
        }
        return .internalDisk
    }
}
