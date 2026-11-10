import SwiftUI

/// 项目存储状态的提示文案。
///
/// 项目目录已从磁盘上消失、或所在设备当前不可达时，界面需要解释原因。
/// 正常状态返回空串，调用方据此决定是否展示提示。
enum ProjectStorageHint {
    /// 存储状态对应的提示文案；正常状态为空串。
    static func text(for kind: ProjectStorageKind) -> String {
        switch kind {
        case .missingDirectory:
            return pluginLocalization.string("This project directory no longer exists on disk.")
        case .unreachableVolume:
            return pluginLocalization.string("This project is on a drive that is not currently available.")
        case .internalDisk, .externalDisk, .networkVolume:
            return ""
        }
    }
}
