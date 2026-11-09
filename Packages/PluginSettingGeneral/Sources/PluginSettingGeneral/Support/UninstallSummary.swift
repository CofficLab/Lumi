import Foundation
import ProviderUninstall

/// 卸载确认页展示的有效处理范围。
///
/// 必须与卸载执行时的过滤规则保持一致：应用本体只在「移到废纸篓」开关打开时
/// 处理，Keychain 凭据只在凭据开关打开时处理，其余 Lumi 数据总会清理。
/// 确认页据此计算项目数、总大小与待处理列表，避免把实际会保留的项目
/// 描述成「将处理」。
struct UninstallSummary: Equatable {
    let targets: [UninstallTarget]

    init(
        scan: UninstallScan,
        removeApplication: Bool,
        removeKeychainCredentials: Bool
    ) {
        targets = scan.targets.filter { target in
            switch target.kind {
            case .application:
                return removeApplication
            case .keychain:
                return removeKeychainCredentials
            default:
                return true
            }
        }
    }

    var totalSizeInBytes: Int64 {
        targets.reduce(0) { $0 + $1.sizeInBytes }
    }
}
