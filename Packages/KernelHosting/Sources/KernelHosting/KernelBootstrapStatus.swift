import Combine
import Foundation

/// 内核启动状态——跨窗口共享的可观察相位。
///
/// `WindowSettings` 与主窗口是两个独立的 SwiftUI 场景,主窗口在
/// `KernelHosting.createKernel` 内完成内核启动(成功或失败)。为了让设置窗口
/// 不必无限轮询 `mainKernel`、也不必在内核启动失败时永远卡在「Loading…」,
/// 把启动相位提升为这一份全局可观察对象。
///
/// - `booting`:内核正在初始化。
/// - `ready`:内核启动成功,`mainKernel` 可解析。
/// - `failed`:内核启动抛错,携带原始错误供界面展示。
///
/// 相位由 `KernelHosting.createKernel` 在启动成功 / 失败时翻转;
/// 其它窗口通过 `@ObservedObject` 观察它,从而随相位变化即时刷新。
@MainActor
public final class KernelBootstrapStatus: ObservableObject {
    public enum Phase {
        case booting
        case ready
        case failed(Error)
    }

    /// 全局共享实例:内核生命周期全局唯一,启动相位亦全局唯一。
    public static let shared = KernelBootstrapStatus()

    @Published public private(set) var phase: Phase = .booting

    private init() {}

    /// 内核启动成功。
    func markReady() {
        phase = .ready
    }

    /// 内核启动失败。已就绪后不再回退,避免覆盖首个成功创建的内核。
    func markFailed(_ error: Error) {
        guard case .ready = phase else {
            phase = .failed(error)
            return
        }
    }
}
