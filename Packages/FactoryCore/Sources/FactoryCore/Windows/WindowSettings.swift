import KernelHosting
import KernelLumi
import LumiUI
import SwiftUI

/// 设置窗口
///
/// 不在构造期快照内核,而是运行期从 `FactoryCore.mainKernel` 解析。
/// 这样即便设置窗口的 SwiftUI Scene 在主窗口内核初始化完成前被求值,
/// 也不会被 `mainKernel ?? KernelLumi()` 锁死成一个空内核实例
/// (空内核没有 settings/theme 等服务,会导致设置界面显示错误界面)。
///
/// 当主内核尚未就绪时显示加载占位;通过 `KernelBootstrapStatus` 观察启动相位:
/// 成功即切到真实设置界面,失败则直接展示错误,而不会无限轮询卡在「Loading…」。
public struct WindowSettings: View {
    /// 观察内核启动相位,替代无限轮询 `mainKernel`。
    /// 主窗口是独立场景,其启动成功 / 失败会翻转该相位;
    /// 失败时这里能展示真正的错误,而非永远卡在「Loading…」。
    @ObservedObject private var bootStatus = KernelBootstrapStatus.shared

    public init() {}

    public var body: some View {
        Group {
            switch bootStatus.phase {
            case .booting:
                SettingsLoadingView()
            case .ready:
                if let kernel = FactoryCore.mainKernel {
                    SettingsView(kernel: kernel)
                } else {
                    // 相位已就绪但 mainKernel 解析为空:理论上不应发生,
                    // 降级显示加载占位,避免空内核撑起设置界面。
                    SettingsLoadingView()
                }
            case .failed(let error):
                CrashedView(error: error)
            }
        }
    }
}

/// 内核尚未就绪时设置窗口的占位视图。
struct SettingsLoadingView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Loading…")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}
