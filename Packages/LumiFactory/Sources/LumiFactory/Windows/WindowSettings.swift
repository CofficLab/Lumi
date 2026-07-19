import LumiKernel
import LumiUI
import SwiftUI

/// 设置窗口
public struct WindowSettings: View {
    let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        SettingsView(kernel: kernel)
    }
}
