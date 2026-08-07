import LumiKernel
import SwiftUI

struct ConversationLanguageToolbarView: View {
    // 仅作为外壳把 kernel 透传给 LanguageToggleButton；自身不订阅 kernel，
    // 避免无谓挂上全局总线。真正的 conversations 订阅在 LanguageToggleButton 内完成。
    let kernel: LumiKernel

    var body: some View {
        LanguageToggleButton(kernel: kernel)
    }
}
