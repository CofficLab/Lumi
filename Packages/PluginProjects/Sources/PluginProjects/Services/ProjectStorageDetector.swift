import Foundation

/// 存储卷特征：区分本机磁盘、外置设备与网络卷。
struct VolumeTraits: Equatable, Sendable {
    /// 是否为本地卷（网络卷为 false）。
    let isLocal: Bool
    /// 是否为内置卷（外置设备为 false）。
    let isInternal: Bool
}

/// 单次存储探测的结果。
///
/// 探测失败有两种截然不同的原因，界面需要区别对待：
///
/// - `missingDirectory`：路径在磁盘上已经不存在——目录被删除或移动。
/// - `unreachableVolume`：路径还在，但读不到卷属性——设备被拔出、挂载点消失。
enum StorageProbeResult: Equatable, Sendable {
    /// 成功读到卷特征。
    case traits(VolumeTraits)
    /// 路径在磁盘上不存在。
    case missingDirectory
    /// 路径存在但卷属性不可读。
    case unreachableVolume
}

/// 探测项目所在存储卷的类型（内置磁盘 / 外置设备 / 网络卷 / 目录缺失 / 卷不可达）。
///
/// ## 为什么单独一层
///
/// 工具栏胶囊与项目列表需要区分「本地磁盘」和「U 盘、移动硬盘」等外置设备，
/// 还要把「项目目录已经不在磁盘上」标成异常状态；但判定依赖文件系统状态，
/// 属于易变信息，不适合塞进持久化的 `ProjectEntry`。
/// 因此这里按需探测 + 内存缓存，避免每次 SwiftUI 重绘都打一次文件系统。
///
/// ## 判定依据
///
/// - `volumeIsInternal == false`：该路径位于外置卷（U 盘、移动硬盘、外置硬盘盒）。
/// - `volumeIsLocal == false`：该路径位于网络卷（NAS、SMB/NFS 挂载）。
/// - 路径不存在：目录已被删除或移动。
/// - 路径存在但卷属性读取失败：设备已拔出或挂载点消失。
@MainActor
enum ProjectStorageDetector {
    /// 探测结果缓存。键为项目路径，值为判定结果。
    private static var cache: [String: ProjectStorageKind] = [:]

    /// 存储探测器。默认读取文件系统；测试可替换以覆盖各类分支。
    nonisolated(unsafe) static var probe: (String) -> StorageProbeResult = { path in
        let url = URL(fileURLWithPath: path)

        // 路径不存在：目录已被删除或移动。
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .missingDirectory
        }

        let keys: Set<URLResourceKey> = [.volumeIsLocalKey, .volumeIsInternalKey]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            // 目录还在，但读不到卷属性：设备已拔出或挂载点消失。
            return .unreachableVolume
        }

        return .traits(
            VolumeTraits(
                isLocal: values.volumeIsLocal ?? true,
                isInternal: values.volumeIsInternal ?? true
            )
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
        switch probe(path) {
        case .missingDirectory:
            return .missingDirectory
        case .unreachableVolume:
            return .unreachableVolume
        case let .traits(traits):
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
}
