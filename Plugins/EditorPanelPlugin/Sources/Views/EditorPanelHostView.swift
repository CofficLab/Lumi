import EditorService
import LumiKernel
import LumiUI
import SwiftUI

public struct EditorPanelHostView: View {
    let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        EditorPanelView(kernel: kernel)
    }
}