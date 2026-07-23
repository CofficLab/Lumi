import LumiKernel
import LumiUI
import SwiftUI

/// 设置窗口
///
/// 不在构造期快照内核,而是运行期从 `LumiFactory.mainKernel` 解析。
/// 这样即便设置窗口的 SwiftUI Scene 在主窗口内核初始化完成前被求值,
/// 也不会被 `mainKernel ?? LumiKernel()` 锁死成一个空内核实例
/// (空内核没有 settings/theme 等服务,会导致设置界面显示错误界面)。
///
/// 当主内核尚未就绪时显示加载占位,并通过轮询驱动切换到真实设置界面。
public struct WindowSettings: View {
    @State private var kernelResolved = false

    public init() {}

    public var body: some View {
        Group {
            if let kernel = LumiFactory.mainKernel {
                SettingsView(kernel: kernel)
            } else {
                SettingsLoadingView()
            }
        }
        .task {
            // 主内核通常先于设置窗口就绪,此循环几乎立即退出;
            // 仅在设置窗口早于主窗口初始化的极端时序下起作用。
            while LumiFactory.mainKernel == nil {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            // 翻转该 state 以驱动 body 重新求值,
            // 使上述 `if let` 切换到已就绪的 mainKernel。
            kernelResolved = true
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
