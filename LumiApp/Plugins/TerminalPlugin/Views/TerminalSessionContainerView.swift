import Foundation
import SwiftUI

struct TerminalSessionContainerView: View {
    @ObservedObject var session: TerminalSession

    var body: some View {
        NativeTerminalHostView(session: session)
        // 背景色由 LumiTerminalView 的 nativeBackgroundColor 管理，
        // 与编辑器主题保持同步，无需额外 SwiftUI 背景
    }
}
