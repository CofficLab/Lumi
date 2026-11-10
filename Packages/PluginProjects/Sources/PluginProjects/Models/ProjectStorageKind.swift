import Foundation

/// 项目所在存储卷的类型。
///
/// 用于在 UI 上区分本机内置磁盘与外置设备（U 盘、移动硬盘、外置硬盘盒等），
/// 并把「目录已从磁盘上消失」这类异常状态单独标出来。
enum ProjectStorageKind: Equatable {
    /// 本机内置磁盘。
    case internalDisk
    /// 外置设备（U 盘、移动硬盘、外置硬盘盒）。
    case externalDisk
    /// 网络卷（NAS、SMB/NFS 挂载）。
    case networkVolume
    /// 项目目录在磁盘上已不存在（目录被删除或移动）。
    case missingDirectory
    /// 目录仍存在，但所在卷不可达（设备被拔出、挂载点消失等）。
    case unreachableVolume

    /// 对应的 SF Symbol 名称。
    var symbolName: String {
        switch self {
        case .internalDisk: "folder"
        case .externalDisk: "externaldrive.fill"
        case .networkVolume: "network"
        case .missingDirectory: "folder.badge.questionmark"
        case .unreachableVolume: "exclamationmark.triangle.fill"
        }
    }

    /// 是否属于「项目不可用」状态。
    ///
    /// 这类项目的目录已经不在磁盘原位，界面需要给出显式标记而不是普通文件夹图标。
    var isUnavailable: Bool {
        switch self {
        case .missingDirectory, .unreachableVolume: true
        case .internalDisk, .externalDisk, .networkVolume: false
        }
    }
}
