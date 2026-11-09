import Foundation

/// 项目所在存储卷的类型。
///
/// 用于在 UI 上区分本机内置磁盘与外置设备（U 盘、移动硬盘、外置硬盘盒等）。
enum ProjectStorageKind: Equatable {
    /// 本机内置磁盘。
    case internalDisk
    /// 外置设备（U 盘、移动硬盘、外置硬盘盒）。
    case externalDisk
    /// 网络卷（NAS、SMB/NFS 挂载）。
    case networkVolume
    /// 路径不可达（设备已拔出或目录已删除）。
    case unavailable

    /// 对应的 SF Symbol 名称。
    var symbolName: String {
        switch self {
        case .internalDisk: "folder"
        case .externalDisk: "externaldrive.fill"
        case .networkVolume: "network"
        case .unavailable: "questionmark.folder"
        }
    }
}
